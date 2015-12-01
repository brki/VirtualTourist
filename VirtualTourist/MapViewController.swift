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

	let client = FlickrClient.sharedClient

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


}

