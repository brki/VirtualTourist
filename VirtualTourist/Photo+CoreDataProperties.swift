//
//  Photo+CoreDataProperties.swift
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

extension Photo {

    @NSManaged var title: String?
    @NSManaged var pin: Pin?
	@NSManaged var flickrID: String


}
