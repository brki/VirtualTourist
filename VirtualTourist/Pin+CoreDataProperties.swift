//
//  Pin+CoreDataProperties.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Pin {

	@NSManaged var latitude: Double
	@NSManaged var longitude: Double
	@NSManaged var relativePath: String
	@NSManaged var photosVersion: Int
	@NSManaged var photos: NSSet

	/**
	One of the Pin.PHOTO_PROCESSING_STATE_* values.
	*/
	@NSManaged var photoProcessingState: Int

	/**
	This will be set if there was an error while getting the photos and the error has not yet been handled by a view controller.
	
	Any view controller that does handle the error (e.g. by displaying a notice to the user or logging the error) should
	set this property to nil after handling it, to avoid another view controller also handling the error.
	*/
	@NSManaged var photoProcessingError: NSError?
}
