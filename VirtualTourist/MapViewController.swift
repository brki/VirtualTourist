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
		// Register the context so that the current state can be saved when the application terminates.
		CoreDataStack.sharedInstance.registerContext(context)

		mapView.delegate = self

		addSavedPinsToMap()
	}

	override func viewWillAppear(animated: Bool) {
		// Do not show navigation bar for this view.
		navigationController?.navigationBar.hidden = true
		super.viewWillAppear(animated)
	}

	override func viewWillDisappear(animated: Bool) {
		// Unhide navigation bar so that the animated transition looks nice.
		navigationController?.navigationBar.hidden = false
		super.viewDidDisappear(animated)
	}

	// Add existing pins to the map.
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
	Long press: start handling dragging and dropping of Pin.
	*/
	@IBAction func handleLongPress(sender: UILongPressGestureRecognizer) {
		let touchPoint = sender.locationInView(self.mapView)
		let coordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)

		if let annotation = draggedAnnotation {
			annotation.coordinate = coordinate
		}

		if sender.state == .Began {

			// Pin is being dragged.
			context.performBlockAndWait {
				self.draggedPin = Pin(latitude: coordinate.latitude, longitude: coordinate.longitude, managedObjectContext: self.context)
			}
			draggedAnnotation = addAnnotationForPin(draggedPin!)

		} else if sender.state == .Ended {

			// Pin has been dropped.
			let droppedPin = draggedPin!
			context.performBlockAndWait {
				droppedPin.latitude = coordinate.latitude
				droppedPin.longitude = coordinate.longitude
			}
			CoreDataStack.saveContext(context)
			PinPhotoDownloadManager.launchOperations(droppedPin)
			draggedAnnotation = nil
			draggedPin = nil
		}
	}

	// Add Pin to map.
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
		PinPhotoDownloadManager.launchOperations(pinAnnotation.pin)

		// Deselect the annotation before pushing, so that it won't be selected when returning to this view controller:
		mapView.selectedAnnotations.removeAll()

		navigationController?.pushViewController(destinationVC, animated: true)
	}
}