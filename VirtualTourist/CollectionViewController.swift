//
//  CollectionViewController.swift
//  VirtualTourist
//
//  Created by Brian on 12/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit
import CoreData

private var PinStatusContext = 0

class CollectionViewController: UIViewController {

	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var messageLabel: UILabel!

	var pin: Pin!
	var hasData = false
	var isObservingPinState = false

	var queuedChanges = [FetchedResultChange]()

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self
		messageLabel.hidden = true
	}

	override func viewWillDisappear(animated: Bool) {
		removePinObserver()
	}

	lazy var fetchedResultsController: NSFetchedResultsController = {
		let context = self.pin.managedObjectContext!

		var frc: NSFetchedResultsController!
		context.performBlockAndWait {
			let fetchRequest = NSFetchRequest(entityName: "Photo")
			fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [self.pin])
			fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
			frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
			do {
				try frc.performFetch()
			} catch {
				print("CollectionViewController: error on fetchedResultsController.performFetch: \(error)")
			}
		}
		frc.delegate = self
		return frc
	}()

	override func viewWillAppear(animated: Bool) {

		// If an ongoing SearchOperation exists for this pin.photosVersion, show a spinner indicator and wait until there is data.
		var state = -1

		pin.managedObjectContext?.performBlockAndWait {
			state = self.pin.photoProcessingState
		}

		print("viewWillAppear: state: \(state)")
		// The presenting view controller will have launched download operations, if necessary.
		switch state {

		case Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS, Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			hasData = true
			showPhotos()

		case Pin.PHOTO_PROCESSING_STATE_NEW, Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA:
			// Still waiting for data; add an observer so we'll get notified when there is data.
			pin.addObserver(self, forKeyPath: "photoProcessingState", options: NSKeyValueObservingOptions.New, context: &PinStatusContext)
			isObservingPinState = true
			showActivityIndicator()

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			// Pop this view controller off the stack, the presenting view controller will show the error.
			self.navigationController?.popViewControllerAnimated(true)

		default:
			print("Unexpected photo processing state: \(pin.photoProcessingState)")
		}
	}

	/**
	Once data is available, present the collection view and photos / placeholder photos.
	*/
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		guard context == &PinStatusContext else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
			return
		}

		guard let state = change?[NSKeyValueChangeNewKey] as? Int else {
			return
		}

		guard let _ = object as? Pin else {
			print("CollectionViewController.observeValueForKeyPath: unexpected object value: \(object)")
			return
		}

		switch state {

		case Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS, Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			hasData = true
			removePinObserver()
			async_main {
				self.showPhotos()
			}

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			// Pop this view controller off the stack, the presenting view controller will show the error.
			async_main {
				self.navigationController?.popViewControllerAnimated(true)
			}

		default:
			break
		}
	}

	func removePinObserver() {
		if isObservingPinState {
			self.isObservingPinState = false
			pin.removeObserver(self, forKeyPath: "photoProcessingState", context: &PinStatusContext)
		}
	}

	func showPhotos() {
		guard let count = fetchedResultsController.fetchedObjects?.count where count > 0 else {
			showNoPhotosMessage()
			return
		}
		showCollectionView()
		collectionView.reloadData()
		print("in showPhotos(), pin status: \(pin.photoProcessingState)")
	}

	func showCollectionView() {
		activityIndicator.stopAnimating()
		collectionView.hidden = false
	}

	func showActivityIndicator() {
		activityIndicator.startAnimating()
		collectionView.hidden = true
	}

	func showNoPhotosMessage() {
		collectionView.hidden = true
		messageLabel.hidden = false
	}
}

extension CollectionViewController: UICollectionViewDataSource {

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		guard hasData else {
			return 0
		}
		return fetchedResultsController.fetchedObjects?.count ?? 0
	}

	/**
	Return custom CollectionViewCell with photo or placeholder image.
	*/
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {

		let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo

		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! CollectionViewCell

		// Assumption: this is called on the main thread, and the photo's context is a main-thread context.
		if photo.downloaded,
			let path = photo.fileURL?.path,
			let image = UIImage(contentsOfFile: path) {

			cell.imageView.image = image
		} else {
			cell.imageView.image = UIImage(named: "Placeholder")
		}
		return cell
	}
}

extension CollectionViewController: NSFetchedResultsControllerDelegate {

	/**
	Collect changes that will be processed in controllerDidChangeContent().
	*/
	func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
		queuedChanges.append(
			FetchedResultChange(object: anObject, changeType: type, indexPath: indexPath, newIndexPath: newIndexPath)
		)
	}

	/**
	Apply all changes that have been collected.
	*/
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		var updated = [NSIndexPath]()
		var deleted = [NSIndexPath]()
		let visiblePaths = collectionView.indexPathsForVisibleItems()
		while let change = self.queuedChanges.popLast() {
			switch change.changeType {

			case .Update:
				if let indexPath = change.indexPath where visiblePaths.contains(indexPath) {
					updated.append(change.indexPath!)
				}

			case .Delete:
				deleted.append(change.indexPath!)
				break

			default:
				print("Unexpected change type in controllerDidChangeContent: \(change.changeType.rawValue), change: \(change)")
			}

		}

		collectionView.performBatchUpdates({

			self.collectionView.reloadItemsAtIndexPaths(updated)
			self.collectionView.deleteItemsAtIndexPaths(deleted)

			},
			completion: nil)
	}
}
