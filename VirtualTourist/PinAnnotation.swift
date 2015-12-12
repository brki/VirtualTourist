//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by Brian on 12/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import MapKit

class PinAnnotation: MKPointAnnotation {
	var pin: Pin

	init(pin: Pin) {
		self.pin = pin
		super.init()
		pin.managedObjectContext!.performBlockAndWait {
			self.coordinate = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
		}
	}
}