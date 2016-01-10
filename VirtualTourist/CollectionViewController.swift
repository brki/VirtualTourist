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
	@IBOutlet weak var newCollectionButton: UIBarButtonItem!

	var pin: Pin!
	var context: NSManagedObjectContext { return pin.managedObjectContext! }
	var hasData = false
	var isObservingPinState = false
	var isShowingPhotos = false

	var queuedChanges = [FetchedResultChange]()

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self
		collectionView.delegate = self
		messageLabel.hidden = true
		newCollectionButton.enabled = false
	}

	override func viewWillAppear(animated: Bool) {
		presentPhotosDependingOnPinState()
	}
	
	override func viewWillDisappear(animated: Bool) {
		removePinObserver()
		CoreDataStack.saveContext(context)
	}

	lazy var fetchedResultsController: NSFetchedResultsController = {

		var frc: NSFetchedResultsController!
		self.context.performBlockAndWait {
			let fetchRequest = NSFetchRequest(entityName: "Photo")
			fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [self.pin])
			fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
			frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
		}
		return frc
	}()

	@IBAction func refreshPhotosForPin(sender: AnyObject) {
		fetchedResultsController.delegate = nil
		newCollectionButton.enabled = false
		messageLabel.hidden = true
		PinPhotoDownloadManager.reloadPhotos(self.pin)
		presentPhotosDependingOnPinState()
	}

	func refreshFetchRequest() {
		context.performBlockAndWait {
			do {
				try self.fetchedResultsController.performFetch()
				self.fetchedResultsController.delegate = self
			} catch {
				print("CollectionViewController: error on fetchedResultsController.performFetch: \(error)")
			}
		}
	}

	/**
	Show photos, or an activity indicator, or a label saying that there are no photos.
	*/
	func presentPhotosDependingOnPinState() {
		// If an ongoing SearchOperation exists for this pin.photosVersion, show a spinner indicator and wait until there is data.
		var state = -1

		context.performBlockAndWait {
			state = self.pin.photoProcessingState
		}

		hasData = false

		// The presenting view controller will have launched download operations, if necessary.
		switch state {

		case Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS:
			hasData = true
			showPhotos()
			// Add observer so that we'll know when the photos are all downloaded.
			addPinObserver()

		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			hasData = true
			removePinObserver()
			showPhotos()

		case Pin.PHOTO_PROCESSING_STATE_NEW, Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA:
			// Still waiting for data; add an observer so we'll get notified when there is data.
			addPinObserver()
			isShowingPhotos = false
			showActivityIndicator()

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

		async_main {
			self.presentPhotosDependingOnPinState()
		}

	}

	func addPinObserver() {
		if !isObservingPinState {
			isObservingPinState = true
			pin.addObserver(self, forKeyPath: "photoProcessingState", options: NSKeyValueObservingOptions.New, context: &PinStatusContext)
		}
	}

	func removePinObserver() {
		if isObservingPinState {
			isObservingPinState = false
			pin.removeObserver(self, forKeyPath: "photoProcessingState", context: &PinStatusContext)
		}
	}

	func showPhotos() {
		if !isShowingPhotos {

			isShowingPhotos = true

			// Perform a fetch of the data.
			refreshFetchRequest()

			var count = 0
			context.performBlockAndWait {
				count = self.fetchedResultsController.fetchedObjects?.count ?? 0
			}

			if count == 0 {
				showNoPhotosMessage()
			} else {
				collectionView.reloadData()
				showCollectionView()
			}
		}

		// If the photo downloading process has completed, enable the collection refresh button.
		context.performBlockAndWait {
			async_main {
				self.newCollectionButton.enabled = self.pin.photoProcessingState == Pin.PHOTO_PROCESSING_STATE_COMPLETE
			}
		}
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
		activityIndicator.stopAnimating()
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

extension CollectionViewController: UICollectionViewDelegate {

	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		context.performBlock {
			if let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as? Photo {
				self.context.deleteObject(photo)
			}
		}
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

		// If all photos have been removed, show the "no photos" message.
		// Note that fetchedResultsController.fetchedObjects.count does not reflect the removed object immediately after deletion,
		// so this check is done here, instead.
		if collectionView.numberOfItemsInSection(0) == 0 {
			self.hasData = false
			async_main {
				self.showNoPhotosMessage()
			}
		}
	}
}
