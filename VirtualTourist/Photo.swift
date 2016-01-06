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

	enum PhotoSize: String {
		case Small = "s"
		case Medium = "m"
	}

	static var persistentStoreContext = CoreDataStack.sharedInstance.managedObjectContext

	var fileURL: NSURL? {
		guard let pinDirectory = self.pin?.directory() else {
			return nil
		}
		return pinDirectory.URLByAppendingPathComponent("\(self.flickrID).jpg")
	}

	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
	}

	init(pin: Pin, photo: FlickrPhoto, order: Int, managedObjectContext context: NSManagedObjectContext) {
		let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
		super.init(entity: entity, insertIntoManagedObjectContext: context)

		self.pin = pin
		self.flickrID = photo.id
		self.order = order
		self.title = photo.title
		self.urlTemplate = photo.urlTemplate
	}

	/**
	Returns a URL with which a photo of the given size can be downloaded from Flickr.
	*/
	func URLForSize(size: PhotoSize) -> NSURL {
		let urlString = self.urlTemplate.stringByReplacingOccurrencesOfString("{size}", withString: size.rawValue)
		return NSURL(string: urlString)!
	}

	override func prepareForDeletion() {
		if let storageURL = fileURL {
			do {
				try NSFileManager.defaultManager().removeItemAtURL(storageURL)
			} catch {
				print ("Error while deleting photo file: \(error)")
			}
		}
		super.prepareForDeletion()
	}

}
