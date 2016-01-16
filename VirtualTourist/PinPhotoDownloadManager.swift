//
//  PinPhotoDownloadManager.swift
//  VirtualTourist
//
//  Created by Brian King on 05/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import Foundation
import CoreData

class PinPhotoDownloadManager {

	/**
	Launch data+photo-downloading or just photo-downloading operations
	for the pin, based on the pin's current photoProcessingState.
	
	Returns true if one or more operations were launched, false otherwise.
	*/
	static func launchOperations(pin: Pin) -> Bool {
		var state = -1
		pin.managedObjectContext!.performBlockAndWait {
			state = pin.photoProcessingState
		}
		var startedOperation = false

		switch state {

		case Pin.PHOTO_PROCESSING_STATE_NEW, Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA:
			pin.managedObjectContext!.performBlockAndWait {
				pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA
			}
			let searchOperation = addSearchOperation(pin)
			searchOperation.completionBlock = {
				// Remove cyclic reference when exiting block:
				defer {
					searchOperation.completionBlock = nil
				}

				// If error was set, the error handler will have taken care of any necessary error handling already.
				guard searchOperation.error == nil else {
					return
				}

				let wasCancelled = searchOperation.cancelled
				let context = pin.managedObjectContext!
				context.performBlockAndWait {
					if wasCancelled {
						// Set photoProcessingState to error state, so that the operation can be re-tried
						// next time the user tries to view the photos.
						pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA
					} else {
						// If no error, and not cancelled, then the downloading photos operation will be starting.
						pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS
					}
				}
				CoreDataStack.saveContext(context)
			}
			addDownloadOperation(pin, dependency: searchOperation)
			startedOperation = true

		case Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS:
			pin.managedObjectContext!.performBlockAndWait {
				pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS
			}
			addDownloadOperation(pin)
			startedOperation = true

		case Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA, Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS:
			// Already fetching data, just let it continue.
			break

		case Pin.PHOTO_PROCESSING_STATE_COMPLETE:
			// Nothing to do.
			break

		default:
			// This was unexpected, so don't do anything other than print something for debugging:
			print("Unexpected call to launchOperation with pin state: \(state)")
		}
		
		return startedOperation
	}

	/**
	Adds a search operation on a serial queue associated with this pin,
	to retrieve information about photos near the pin's geographical location.
	*/
	static func addSearchOperation(pin: Pin) -> ErrorAwareOperation {
		let searchOperation = SearchOperation(pin: pin, maxPages: Constant.maxPhotoPagesPerCollection, perPage: Constant.photosPerPage)
		searchOperation.downloadErrorHandler = { error in
			handlePhotoProcessingError(pin,
				state: Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA,
				alertTitle: "Error while fetching photo information",
				error: error
			)
		}
		QueueManager.serialQueueForPin(pin).addOperation(searchOperation)
		return searchOperation
	}

	/**
	Adds a download operation on the concurrency-limited filesDownloadQueue.
	
	If the operation completes successfully (e.g. all photos are downloaded),
	then the pin's photoProcessingState is marked complete (and the context is saved).
	*/
	static func addDownloadOperation(pin: Pin, dependency: NSOperation? = nil) {
		let downloadFilesOperation = DownloadFilesOperation(pin: pin)
		if let dependency = dependency {
			downloadFilesOperation.addDependency(dependency)
		}
		downloadFilesOperation.completionBlock = {
			pin.managedObjectContext?.performBlock {
				// Release the completion block when exiting to break the retain cycle between the
				// DownloadFilesOperation and this block:
				// (Note: [unowned downloadFilesOperation] in ... didn't work here)
				defer {
					downloadFilesOperation.completionBlock = nil
				}

				// Error handler would have been called if error is set, so no need to handle that here.
				guard downloadFilesOperation.error == nil else {
					return
				}

				var needsSave = false

				if downloadFilesOperation.cancelled {
					// If a dependendant operation already set the error state, leave it like that.
					// Otherwise, if the operation was cancelled, mark it with an appropriate error state so that
					// processing can be retried next time the user tries to view the pin's photos.
					if !pin.photoProcessingStateIsError {
						pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS
						needsSave = true
					}
				} else {
					pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_COMPLETE
					needsSave = true
				}

				if needsSave {
					CoreDataStack.saveContext(pin.managedObjectContext!)
				}
			}
		}
		downloadFilesOperation.downloadErrorHandler = { error in
			handlePhotoProcessingError(pin,
				state: Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS,
				alertTitle: "Error while downloading photos",
				error: error
			)
		}

		QueueManager.filesDownloadQueue.addOperation(downloadFilesOperation)
	}

	static func handlePhotoProcessingError(pin: Pin, state: Int, alertTitle: String, error: NSError) {

		savePinWithState(pin, state: state)

		// Show an error message on the foreground view controller:
		Utility.presentAlert(alertTitle, message: error.localizedDescription)

		// Log details, if present.
		if let underlyingError = error.userInfo["underlyingError"] {
			print("Error while fetching data / photos (photoProcessingState: \(state): \(underlyingError)")
		}
	}

	static func savePinWithState(pin: Pin, state: Int) {
		let context = pin.managedObjectContext!

		context.performBlockAndWait {
			pin.photoProcessingState = state
		}
		CoreDataStack.saveContext(context)
	}

	static func reloadPhotos(pin: Pin) {
		var oldVersion = -1
		let context = pin.managedObjectContext!
		context.performBlockAndWait {
			oldVersion = pin.photosVersion
			pin.photosVersion += 1
			pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_NEW
			pin.photos = NSSet()
		}
		CoreDataStack.saveContext(context)

		// Remove the previous version directory, with all photos.
		pin.deleteDirectoryForVersion(oldVersion)

		// Start loading new photos:
		launchOperations(pin)
	}

	/**
	Adjusts pin status on startup.  If the application crashed or was killed while fetching photo information for a pin
	or downloading photos for a pin, the pin's photoProcessingState should be adjusted to reflect that that operation
	did not sucessfully complete.
	*/
	static func adjustPinStatusAtApplicationStartup() {
		let context = CoreDataStack.sharedInstance.managedObjectContext

		let request = NSBatchUpdateRequest(entityName: "Pin")
		request.propertiesToUpdate = ["photoProcessingState": Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA]
		request.predicate = NSPredicate(format: "photoProcessingState = %@", Pin.PHOTO_PROCESSING_STATE_FETCHING_DATA as NSNumber)
		request.resultType = .StatusOnlyResultType

		let request2 = NSBatchUpdateRequest(entityName: "Pin")
		request2.propertiesToUpdate = ["photoProcessingState": Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS]
		request2.predicate = NSPredicate(format: "photoProcessingState = %@", Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS as NSNumber)
		request2.resultType = .StatusOnlyResultType

		context.performBlock {
			do {
				try context.executeRequest(request)
				try context.executeRequest(request2)
			} catch {
				print("Error while adjusting pin status: \(error)")
			}
		}
	}
}