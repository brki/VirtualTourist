//
//  PinPhotoDownloadManager.swift
//  VirtualTourist
//
//  Created by Brian King on 05/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import Foundation

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

				guard searchOperation.error == nil else {
					return
				}
				pin.managedObjectContext!.performBlockAndWait {
					pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_FETCHING_PHOTOS
				}
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
		let searchOperation = SearchOperation(pin: pin, maxPhotos: Constant.MaxPhotosPerPin)
		searchOperation.downloadErrorHandler = { error in
			pin.managedObjectContext?.performBlockAndWait {
				pin.photoProcessingError = error
				pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA
			}
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
				// Release the completion block when exiting to break the retain cycle.  [unowned downloadFilesOperation] in ... didn't work here.
				defer {
					downloadFilesOperation.completionBlock = nil
				}

				guard pin.photoProcessingError == nil else {
					return
				}

				if !downloadFilesOperation.cancelled {
					pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_COMPLETE
					CoreDataStack.saveContext(pin.managedObjectContext!)
				}
			}
		}
		downloadFilesOperation.downloadErrorHandler = { error in
			pin.managedObjectContext!.performBlockAndWait {
				pin.photoProcessingError = error
				pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS
			}
		}

		QueueManager.filesDownloadQueue.addOperation(downloadFilesOperation)
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
}