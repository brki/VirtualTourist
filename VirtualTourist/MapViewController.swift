//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit
import MapKit
import CoreData

// TODO perhaps: use a custom annotationview that hold a reference to the pin, to allow deleting the pin
//               via a button on the callout view.

private var PinStatusContext = 0

class MapViewController: UIViewController {

	let ANNOTATION_VIEW_IDENTIFIER = "mvc_avi"
	let client = FlickrClient.sharedClient
	let context = CoreDataStack.sharedInstance.childContext(.MainQueueConcurrencyType)
	var draggedAnnotation: MKPointAnnotation?
	var draggedPin: Pin?

	@IBOutlet weak var mapView: MKMapView!
	override func viewDidLoad() {
		super.viewDidLoad()
		mapView.delegate = self
		addSavedPinsToMap()
		// Do any additional setup after loading the view, typically from a nib.
	}

	override func viewWillAppear(animated: Bool) {
		navigationController?.navigationBar.hidden = true
		super.viewWillAppear(animated)
	}

	override func viewWillDisappear(animated: Bool) {
		navigationController?.navigationBar.hidden = false
		super.viewDidDisappear(animated)
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}

	func addSavedPinsToMap() {
		var pins: [Pin]
		do {
			pins = try context.executeFetchRequest(NSFetchRequest(entityName: "Pin")) as! [Pin]
		} catch {
			print("Error loading pins from storage: \(error)")
			showErrorAlert("Unable to retrieve saved map pins")
			return
		}
		for pin in pins {
			addAnnotationForPin(pin)
		}
	}

	/**
	Long press: add Pin annotation.
	*/
	@IBAction func handleLongPress(sender: UILongPressGestureRecognizer) {
		let touchPoint = sender.locationInView(self.mapView)
		let coordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)

		if let annotation = draggedAnnotation {
			annotation.coordinate = coordinate
		}

		if sender.state == .Began {
			context.performBlockAndWait {
				self.draggedPin = Pin(latitude: coordinate.latitude, longitude: coordinate.longitude, managedObjectContext: self.context)
			}
			draggedAnnotation = addAnnotationForPin(draggedPin!)
		} else if sender.state == .Ended {
			let droppedPin = draggedPin!
			context.performBlockAndWait {
				droppedPin.latitude = coordinate.latitude
				droppedPin.longitude = coordinate.longitude
			}
			launchOperations(droppedPin)
			draggedAnnotation = nil
			draggedPin = nil
		}
	}

	func launchOperations(pin: Pin) {
		var state = -1
		pin.managedObjectContext!.performBlockAndWait {
			state = pin.photoProcessingState
		}

		switch state {

		case Pin.PHOTO_PROCESSING_STATE_NEW, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA:
			let searchOperation = addSearchOperation(pin)
			addDownloadOperation(pin, dependency: searchOperation)

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			addDownloadOperation(pin)

		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			// Nothing to do.
			break

		default:
			// This was unexpected, and the rest of the function should not be executed:
			print("Unexpected call to launchOperation with pin state: \(state)")
			return
		}

		startMontoringPhotoProcessingState(pin)
	}
	
	func addSearchOperation(pin: Pin) -> NSOperation {
		let searchOperation = SearchOperation(pin: pin, maxPhotos: Constant.MaxPhotosPerPin)
//		searchOperation.completionBlock = {
//			pin.managedObjectContext?.performBlock {
//				// If there was an error, the context will already have been saved:
//				guard pin.photoProcessingError == nil else {
//					return
//				}
//				CoreDataStack.saveContext(pin.managedObjectContext!)
//			}
//		}

		QueueManager.serialQueueForPin(pin).addOperation(searchOperation)

		return searchOperation
	}

	func addDownloadOperation(pin: Pin, dependency: NSOperation? = nil) {
		let downloadFilesOperation = DownloadFilesOperation(pin: pin)
		if let dependency = dependency {
			downloadFilesOperation.addDependency(dependency)
		}
		downloadFilesOperation.completionBlock = {
			pin.managedObjectContext?.performBlock {
				guard pin.photoProcessingError == nil else {
					return
				}
				if !downloadFilesOperation.cancelled {
					pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_COMPLETE
					CoreDataStack.saveContext(pin.managedObjectContext!)
				}
			}
		}

		QueueManager.filesDownloadQueue.addOperation(downloadFilesOperation)
	}

	// Monitor pin.photoProcessingState, so that an error can be reported if one happened.
	func startMontoringPhotoProcessingState(pin: Pin) {
		pin.addObserver(self, forKeyPath: "photoProcessingState", options: NSKeyValueObservingOptions.New, context: &PinStatusContext)
	}

	/**
	If an error occurred while downloading the photos, notify the user.
	*/
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		guard context == &PinStatusContext else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
			return
		}

		guard let state = change?[NSKeyValueChangeNewKey] as? Int else {
			return
		}

		guard let pin = object as? Pin else {
			print("MapViewController.observeValueForKeyPath: unexpected object value: \(object)")
			return
		}

		var finished = false

		switch state {
		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			// Data and photo downloading tasks completed without error.
			finished = true

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			finished = true
			guard let error = pin.photoProcessingError else {
				break
			}

			pin.managedObjectContext?.performBlockAndWait {
				pin.photoProcessingError = nil
			}

			let title = state == Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA ? "Error fetching data" : "Error while downloading photos"
			self.showErrorAlert(title, message: error.localizedDescription, completion: nil)
			if let underlyingError = error.userInfo["underlyingError"] {
				print("Error while fetching data / photos: \(underlyingError)")
			}

		default:
			break
		}

		if finished {
			pin.removeObserver(self, forKeyPath: "photoProcessingState", context: &PinStatusContext)
		}
	}

	func addAnnotationForPin(pin: Pin) -> MKPointAnnotation {
		let annotation = PinAnnotation(pin: pin)
		mapView.addAnnotation(annotation)
		return annotation
	}

	func showErrorAlert(title: String, message: String? = nil, completion: (() ->Void)? = nil) {
		let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
		alertController.addAction(
			UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil)
		)
		async_main {
			self.presentViewController(alertController, animated: true, completion: completion)
		}
	}
}

extension MapViewController: MKMapViewDelegate {

	func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
		var annotationView: MKAnnotationView
		if let view = mapView.dequeueReusableAnnotationViewWithIdentifier(ANNOTATION_VIEW_IDENTIFIER) {
			annotationView = view
		} else {
			annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: ANNOTATION_VIEW_IDENTIFIER)
		}
		return annotationView
	}

	func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
		guard let pinAnnotation = view.annotation as? PinAnnotation,
			destinationVC = storyboard?.instantiateViewControllerWithIdentifier("CollectionVC") as? CollectionViewController else {
				return
		}
		destinationVC.pin = pinAnnotation.pin

		// In case the photo data / photos have not yet been downloaded (for example due to a previous network error), retry:
		launchOperations(pinAnnotation.pin)

		// Deselect the annotation before pushing, so that it won't be selected when returning to this view controller:
		mapView.selectedAnnotations.removeAll()

		navigationController?.pushViewController(destinationVC, animated: true)
	}
}