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

	static let PHOTO_PROCESSING_STATE_NEW = 0
	static let PHOTO_PROCESSING_STATE_FETCHING_DATA = 1
	static let PHOTO_PROCESSING_STATE_FETCHING_PHOTOS = 2
	static let PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA = 3
	static let PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS = 4
	static let PHOTO_PROCESSING_STATE_COMPLETE = 5

	// todo: add errorWasHandled property?

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
			// Create the directory if it doesn't already exist (if it does exist, this will not throw an error):
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
