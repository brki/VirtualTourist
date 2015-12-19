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
			getAssociatedPhotos(draggedPin!)
			draggedAnnotation = nil
			draggedPin = nil
		}
	}

	func getAssociatedPhotos(pin: Pin) {
		let searchOperation = SearchOperation(pin: pin, maxPhotos: Constant.MaxPhotosPerPin)
		searchOperation.completionBlock = {

			if let error = searchOperation.error {
				self.showErrorAlert("Fetch error", message: error.localizedDescription)
				return
			}

			guard let pinContext = pin.managedObjectContext else {
				self.showErrorAlert("Data Storage error", message: "Pin is not associated with a context")
				return
			}

			var childContextSaved = false
			pinContext.performBlockAndWait {
				do {
					// Push the changes up to the parent context:
					try pinContext.save()
					childContextSaved = true
				} catch {
					print("Error saving child context: \(error)")
					self.showErrorAlert("Error saving fetched photo information", message: "Unable to stage data for saving")
				}
			}
			guard childContextSaved else {
				return
			}
			// Save the parent context on the private queue:
			let privateQueueContext = pinContext.parentContext!
			privateQueueContext.performBlock {
				do {
					try privateQueueContext.save()
				} catch {
					print("Error saving parent context: \(error)")
					self.showErrorAlert("Error saving fetched photo information", message: "Unable to persist data")
				}
			}
		}

		let downloadFilesOperation = DownloadFilesOperation(pin: pin)
		downloadFilesOperation.addDependency(searchOperation)

		OperationMap.PinSearchOperation[pin] = searchOperation

		searchOperation.start()
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

		// Deselect the annotation before pushing, so that it won't be selected when returning to this view controller:
		mapView.selectedAnnotations.removeAll()

		navigationController?.pushViewController(destinationVC, animated: true)
	}
}