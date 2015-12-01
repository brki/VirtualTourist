//
//  MapViewController.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

	let ANNOTATION_VIEW_IDENTIFIER = "mvc_avi"
	let client = FlickrClient.sharedClient
	let context = CoreDataStack.sharedInstance.managedObjectContext
	var draggedAnnotation: MKPointAnnotation?
	var draggedPin: Pin?


	@IBOutlet weak var mapView: MKMapView!
	override func viewDidLoad() {
		super.viewDidLoad()

		client.searchLocation(1, latitude: 46.8, longitude: 7.15)  { jsonObject, response, error in
			print(response)
			guard error == nil else {
				print("error: \(error)")
				return
			}
			print(jsonObject)
		}

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
			draggedPin = Pin(latitude: coordinate.latitude, longitude: coordinate.longitude, managedObjectContext: context)
			draggedAnnotation = addAnnotationForPin(draggedPin!)
		} else if sender.state == .Ended {
			// TODO: save context
			draggedAnnotation = nil
			draggedPin = nil
		}
	}

	func addAnnotationForPin(pin: Pin) -> MKPointAnnotation {
		let annotation = MKPointAnnotation()
		annotation.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
		mapView.addAnnotation(annotation)
		return annotation
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