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
		case ErrorFetchingPhotoInfo = 6
	}

	let client = FlickrClient.sharedClient
	let photoSize: Photo.PhotoSize
	let pin: Pin

	init(pin: Pin, photoSize: Photo.PhotoSize = .Medium) {

		self.pin = pin
		self.photoSize = photoSize

		super.init()
		self.errorDomain = "DownloadFilesOperation"
		self.shoudSetErrorIfAnyDependencyHasError = false

		// Add an observer so that this operation can be marked as finished when the queue operation count drops to zero.
		concurrentQueue.addObserver(self, forKeyPath: "operationCount", options: .New, context: &downloadFilesOperationObserverContext)
	}

	deinit {
		print("deinit DownloadFilesOperation object")
		concurrentQueue.removeObserver(self, forKeyPath: "operationCount")
	}

	override func startExecution() {

		// Release the dependencies so that they can be deinitialized already:
		while dependencies.count > 0 {
			removeDependency(dependencies[0])
		}

		guard let pinContext = pin.managedObjectContext else {
			self.error = makeNSError(ErrorCode.PinHasNoContext.rawValue, localizedDescription: "Pin is not associated with a context")
			self.handleEndOfExecution()
			return
		}

		var photoList: [Photo]?
		var fetchError: NSError?
		pinContext.performBlockAndWait {
			let fetchRequest = NSFetchRequest(entityName: "Photo")
			fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [self.pin])
			fetchRequest.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
			do {
				photoList = try pinContext.executeFetchRequest(fetchRequest) as? [Photo]
			} catch let error as NSError {
				fetchError = error
			}
		}

		if self.cancelled {
			return
		}

		if let error = fetchError {
			print("Error fetching photoList: \(error)")
			self.error = makeNSError(ErrorCode.ErrorFetchingPhotoInfo.rawValue, localizedDescription: "Error fetching photo information", underlyingError: error)
			handleEndOfExecution()
			return
		}

		if let photos = photoList {
			if photos.count == 0 {
				handleEndOfExecution()
			} else {
				downloadPhotos(photos)
			}
		}

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
			
			operations.append(operation)
		}

		if cancelled {
			return
		}

		concurrentQueue.addOperations(operations, waitUntilFinished: false)
	}

	override func cleanup() {
		print("In DownloadFilesOperation cleanup")  // TODO: remove
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		if finished {
			return
		}
		concurrentQueue.cancelAllOperations()
		callDownloadErrorHandler()
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