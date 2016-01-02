//
//  FetchedResultsChange.swift
//  VirtualTourist
//
//  Created by Brian on 02/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import Foundation
import CoreData

struct FetchedResultChange {
	let object: AnyObject
	let changeType: NSFetchedResultsChangeType
	let indexPath: NSIndexPath?
	let newIndexPath: NSIndexPath?
}