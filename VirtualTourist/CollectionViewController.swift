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

	var pin: Pin!

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self
	}

	override func viewWillAppear(animated: Bool) {

		// If an ongoing SearchOperation exists for this pin.photosVersion, show a spinner indicator and wait until
		var state = -1

		pin.managedObjectContext?.performBlockAndWait {
			state = self.pin.photoProcessingState
		}
		switch state {

		case Pin.PHOTO_PROCESSING_STATE_NEW, Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA:
			showActivityIndicator()
			pin.addObserver(self, forKeyPath: "photosProcessingState", options: NSKeyValueObservingOptions.New, context: &PinStatusContext)

		case Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS:
			// Photo data is available, and photos are currently being downloaded.
			break

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA:
			// TODO: or should this be checked by parent VC before calling?
			print("Todo: retry fetching data + downloading photos")

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			// TODO: or should this be checked by parent VC before calling?
			print("Todo: retry downloading photos")

		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			showPhotos()

		default:
			print("Unexpected photo processing state: \(pin.photoProcessingState)")
		}
	}

	/**
	TODO: doc
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
		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			removePinObserver()
			showPhotos()

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			// Pop this view controller off the stack, the presenting view controller will show the error.
			// TODO: revisit this.  Should parent VC method be invoked to start downloading photos, so that this logic remains valid?
			navigationController?.popViewControllerAnimated(true)
		default:
			break
		}
	}

	func removePinObserver() {
		pin.removeObserver(self, forKeyPath: "photosProcessingState", context: &PinStatusContext)
	}

	func showPhotos() {
		print("in showPhotos(), pin status: \(pin.photoProcessingState)")
		let context = pin.managedObjectContext!
		let fetchRequest = NSFetchRequest(entityName: "Photo")
		fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [pin])
	}

	func showCollectionView() {
		activityIndicator.stopAnimating()
		collectionView.hidden = false
	}

	func showActivityIndicator() {
		activityIndicator.startAnimating()
		collectionView.hidden = true
	}


}

extension CollectionViewController: UICollectionViewDataSource {

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 20
	}

	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath)
		let imageView = UIImageView(frame: cell.contentView.frame)
		imageView.contentMode = .ScaleAspectFit
		imageView.image = UIImage(named: "Placeholder")
		cell.contentView.addSubview(imageView)
		return cell
	}
}
