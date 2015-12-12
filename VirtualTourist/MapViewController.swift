//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit
import MapKit

// TODO perhaps: use a custom annotationview that hold a reference to the pin, to allow deleting the pin
//               via a button on the callout view.

class MapViewController: UIViewController {

	let ANNOTATION_VIEW_IDENTIFIER = "mvc_avi"
	let client = FlickrClient.sharedClient
	let context = CoreDataStack.sharedInstance.managedObjectContext
	var draggedAnnotation: MKPointAnnotation?
	var draggedPin: Pin?

    // TODO: move this elsewhere:
    var searchOperationMap = [Pin: SearchOperation]()

	@IBOutlet weak var mapView: MKMapView!
	override func viewDidLoad() {
		super.viewDidLoad()

//		client.searchLocation(1, latitude: 46.8, longitude: 7.15)  { jsonObject, response, error in
//			print(response)
//			guard error == nil else {
//				print("error: \(error)")
//				return
//			}
//			print(jsonObject)
//		}

		// Do any additional setup after loading the view, typically from a nib.
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
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
        // TODO: save context
        let operation = SearchOperation(pin: pin, maxPhotos: 600)
        searchOperationMap[pin] = operation
        operation.start()
	}

	func addAnnotationForPin(pin: Pin) -> MKPointAnnotation {
		let annotation = MKPointAnnotation()
        context.performBlockAndWait {
            annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
        }
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
}