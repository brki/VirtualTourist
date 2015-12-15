//
//  Pin.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation
import CoreData


class Pin: NSManagedObject {

	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}

	init(latitude: Double, longitude: Double, managedObjectContext context: NSManagedObjectContext) {
		let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.latitude = latitude
		self.longitude = longitude
		self.relativePath = NSUUID().UUIDString
	}

	func directory(var version: Int? = nil) -> NSURL? {
		if version == nil {
			version = self.photosVersion
		}
		var url: NSURL? = Constant.documentDir.URLByAppendingPathComponent(self.relativePath + "-\(version)")
		do {
			try NSFileManager.defaultManager().createDirectoryAtURL(url!, withIntermediateDirectories: true, attributes: nil)
		} catch {
			print("There was an error creating (or ensuring that it exists) the directory for URL: \(url): \(error)")
			url = nil
		}
		return url
	}

	func deleteDirectoryForVersion(version: Int) -> Bool {
		guard let url = directory() else {
			print("Unable to get directory URL for version \(version)")
			return false
		}
		do {
			try NSFileManager.defaultManager().removeItemAtURL(url)
			return true
		} catch {
			print("There was an error creating (or ensuring that it exists) the directory for URL: \(url): \(error)")
			return false
		}
	}

}
