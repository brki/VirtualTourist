//
//  CoreDataStack.swift
//  VirtualTourist
//
//  Created by Brian King on 28/11/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import CoreData

class CoreDataStack {

	typealias saveCompletionHandler = ((error: NSError?, isChildContext: Bool) -> Void)
	
	static let sharedInstance = CoreDataStack()

	static func childContextForContext(context: NSManagedObjectContext, concurrencyType: NSManagedObjectContextConcurrencyType = .MainQueueConcurrencyType) -> NSManagedObjectContext {
		let childContext = NSManagedObjectContext(concurrencyType: concurrencyType)
		childContext.parentContext = context
		return childContext
	}

	/**
	Saves the given context and any ancestor contexts, too.
	
	The handler will be called when the final save completes, or when an error occurs.
	*/
	static func saveContext(context: NSManagedObjectContext, includeParentContexts: Bool = true, handler: saveCompletionHandler? = nil) {

		let isChildContext = context.parentContext != nil

		func saveCurrentContext(completion: () -> Void) {
			var nserror: NSError?
			if context.hasChanges {
				do {
					try context.save()
				} catch {
					nserror = error as NSError
					handler?(error: nserror, isChildContext: isChildContext)
				}
				completion()
			}
		}

		if isChildContext {
			context.performBlock {
				saveCurrentContext {
					if includeParentContexts, let parentContext = context.parentContext {
						CoreDataStack.saveContext(parentContext, includeParentContexts: true, handler: handler)
					} else {
						handler?(error: nil, isChildContext: true)
					}
				}
			}
		} else {
			context.performBlock {
				saveCurrentContext {
					handler?(error: nil, isChildContext: false)
				}
			}
		}
	}

	// Contexts that will be saved when saveAllRegisteredContexts() is called.
	var registeredContexts = Set<NSManagedObjectContext>()

	func registerContext(context: NSManagedObjectContext) {
		registeredContexts.insert(context)
	}

	func saveAllRegisteredContexts() {
		for context in registeredContexts {
			CoreDataStack.saveContext(context)
		}
	}

	lazy var applicationDocumentsDirectory: NSURL = {
		// The directory the application uses to store the Core Data store file. This code uses a directory named "ch.truckin.VirtualTourist" in the application's documents Application Support directory.
		let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
		return urls[urls.count-1]
	}()

	lazy var managedObjectModel: NSManagedObjectModel = {
		// The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
		let modelURL = NSBundle.mainBundle().URLForResource("VirtualTourist", withExtension: "momd")!
		return NSManagedObjectModel(contentsOfURL: modelURL)!
	}()

	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
		// The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
		// Create the coordinator and store
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
		let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
		var failureReason = "There was an error creating or loading the application's saved data."
		do {
			try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
		} catch {
			// Report any error we got.
			var dict = [String: AnyObject]()
			dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
			dict[NSLocalizedFailureReasonErrorKey] = failureReason

			dict[NSUnderlyingErrorKey] = error as NSError
			let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
			// Replace this with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
			abort()
		}

		return coordinator
	}()

	lazy var managedObjectContext: NSManagedObjectContext = {
		let coordinator = self.persistentStoreCoordinator
		var managedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
		managedObjectContext.persistentStoreCoordinator = coordinator
		return managedObjectContext
	}()

	func childContext(concurrencyType: NSManagedObjectContextConcurrencyType) -> NSManagedObjectContext {
		return CoreDataStack.childContextForContext(managedObjectContext, concurrencyType: concurrencyType)
	}
}
