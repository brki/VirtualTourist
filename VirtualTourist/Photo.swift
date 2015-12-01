//
//  Photo.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation
import CoreData


class Photo: NSManagedObject {

	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}

	init(pin: Pin, info: [String: AnyObject], managedObjectContext context: NSManagedObjectContext) {
		let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)


		self.pin = pin
		self.flickrID = String(info["id"] as! Int)
		if let title = info["title"] as? String {
			self.title = title
		}
	}

}
