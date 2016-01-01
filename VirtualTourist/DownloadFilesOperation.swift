//
//  DownloadFilesOperation.swift
//  VirtualTourist
//
//  Created by Brian on 13/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

import Foundation
import CoreData


private var downloadFilesOperationObserverContext = 0


class DownloadFilesOperation: ConcurrentDownloadOperation {

	enum ErrorCode: Int {
		case ErrorGettingSavePath = 1
		case NoData = 2
		case PinHasNoContext = 3
		case SavingPinContextFailed = 4
		case SavingPinParentContextFailed = 5
	}

	let client = FlickrClient.sharedClient
	let photoSize: Photo.PhotoSize
	let pin: Pin

	init(pin: Pin, photoSize: Photo.PhotoSize = .Medium) {

		self.pin = pin
		self.photoSize = photoSize

		super.init()

		// Add an observer so that this operation can be marked as finished when the queue operation count drops to zero.
		concurrentQueue.addObserver(self, forKeyPath: "operationCount", options: .New, context: &downloadFilesOperationObserverContext)
	}

	deinit {
		concurrentQueue.removeObserver(self, forKeyPath: "operationCount")
	}

	override func startExecution() {

		guard let pinContext = pin.managedObjectContext else {
			self.error = makeNSError(ErrorCode.PinHasNoContext.rawValue, localizedDescription: "Pin is not associated with a context")
			self.handleEndOfExecution()
			return
		}

		let fetchRequest = NSFetchRequest(entityName: "Photo")
		fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [pin])
		var photoList: [Photo]!
// This block-ing isn't necessary, I think:
//		pinContext.performBlock {
			do {
				photoList = try pinContext.executeFetchRequest(fetchRequest) as! [Photo]
				downloadPhotos(photoList)
//				self.downloadPhotos(photoList)
			} catch {
				print("Error fetching photoList: \(error)")
			}
//		}

	}

	func downloadPhotos(photos: [Photo]) {
		var operations = [NSOperation]()
		for photo in photos {
			var photoAlreadyDownloaded = false
			var photoID: String!
			var url: NSURL!
			var saveToFileURL: NSURL?

			photo.managedObjectContext!.performBlockAndWait {
				photoAlreadyDownloaded = photo.downloaded
				url = photo.URLForSize(self.photoSize)
				photoID = photo.flickrID
				saveToFileURL = photo.fileURL
			}

			guard !photoAlreadyDownloaded else {
				continue
			}

			guard let fileURL = saveToFileURL else {
				self.error = self.makeNSError(ErrorCode.ErrorGettingSavePath.rawValue, localizedDescription: "Unable to get file saving path for photo with id \(photoID)")
				self.handleEndOfExecution()
				return
			}

			let operation = DownloadSingleFileOperation(url: url) { data, error in

				if self.cancelled {
					return
				}

				if let err = error {
					self.error = err
					self.handleEndOfExecution()
					return
				}

				guard let fileData = data else {
					self.error = self.makeNSError(ErrorCode.NoData.rawValue, localizedDescription: "No data returned, no error information available")
					self.handleEndOfExecution()
					return
				}

				fileData.writeToURL(fileURL, atomically: true)

				// Update the photo record with the fact that it has been downloaded.
				// This will send a notification, so interested parties can observe this change.
				photo.managedObjectContext?.performBlock {
					photo.downloaded = true
				}
			}
			
			//operation.addDependency(self)  // WTF?
			operations.append(operation)
		}

		if cancelled {
			return
		}

		concurrentQueue.addOperations(operations, waitUntilFinished: false)
	}

	override func cleanup() {
		print("In DownloadFilesOperation cleanup")  // TODO: remove
		concurrentQueue.cancelAllOperations()
		if let err = error {
			pin.photoProcessingError = err
			pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_DOWNLOADING_PHOTOS
		}
		persistData()
		super.cleanup()
	}

	func persistData() {
		CoreDataStack.saveContext(pin.managedObjectContext!, includeParentContexts: true) { error, isChildContext in
			guard let err = error else {
				return
			}

			if isChildContext {
				print("Error saving child context: \(err)")
				self.error = self.makeNSError(ErrorCode.SavingPinContextFailed.rawValue, localizedDescription: "Unable to persist photo downloaded state to child context", underlyingError: err)
			} else {
				print("Error saving parent context: \(err)")
				self.error = self.makeNSError(ErrorCode.SavingPinParentContextFailed.rawValue, localizedDescription: "Unable to persist photo downloaded state to parent context", underlyingError: err)
			}
		}
	}

	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		guard context == &downloadFilesOperationObserverContext else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
			return
		}

		guard let path = keyPath where path == "operationCount" else {
			return
		}

		if let newValue = change?[NSKeyValueChangeNewKey] as? Int where newValue == 0 {
			handleEndOfExecution()
		}
	}
	
}