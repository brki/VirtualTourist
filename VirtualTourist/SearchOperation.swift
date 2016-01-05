//
//  SearchOperation.swift
//  VirtualTourist
//
//  Created by Brian on 09/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation
import CoreData

class SearchOperation: ConcurrentDownloadOperation {

	deinit {
		print("deinit of SearchOperation")
	}
	
	enum ErrorCode: Int {
		case ErrorFetchingPhotoList = 1
		case UnexpectedHTTPResponseCode = 2
		case UnexpectedHTTPResponseFormat = 3
		case PinHasNoContext = 4
		case SavingPinContextFailed = 5
		case SavingPinParentContextFailed = 6
	}

	var pin: Pin
	let client = FlickrClient.sharedClient
	var photosAdded = 0
	var maxPhotos: Int
	var _pagesProcessed = 0
	var pagesProcessed: Int {
		get {
			return _pagesProcessed
		}
		set {
			objc_sync_enter(self)
			_pagesProcessed = newValue
			objc_sync_exit(self)
		}
	}

	init(pin: Pin, maxPhotos: Int) {
		self.pin = pin
		self.maxPhotos = maxPhotos
		super.init()
		self.errorDomain = "SearchOperation"
	}

	override func startExecution() {
		let firstPageTask = fetchResultsPage(1) { searchResponse in
			if self.cancelled {
				return
			}
			self.addPhotosToContext(searchResponse.photos)
			self.pagesProcessed += 1
			let responsePhotoCount = searchResponse.photos.count
			if searchResponse.pages > 1 && self.maxPhotos > responsePhotoCount {
				self.getMoreResponsePages(searchResponse)
			} else {
				// There are no photos, or no more pages of photos
				self.handleEndOfExecution()
			}
		}
		self.sessionTasks["1"] = firstPageTask
	}

	func getMoreResponsePages(response: FlickrPhotoSearchResponse) {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}

		guard !cancelled && error == nil else {
			return
		}

		let needed = maxPhotos - photosAdded
		guard needed > 0 else {
			return
		}

		let neededPages = Int(ceil(Float(needed) / Float(response.perpage)))
		let availablePages = min(neededPages, response.pages - pagesProcessed)

		for i in pagesProcessed + 1 ... pagesProcessed + availablePages {
			// Launch more URLSessionTasks using a concurrent queue.
			self.concurrentQueue.addOperationWithBlock {
				let task = self.fetchResultsPage(i) { searchResponse in

					guard !self.cancelled && self.error == nil else {
						return
					}

					self.addPhotosToContext(searchResponse.photos)
					self.pagesProcessed += 1

					if self.pagesProcessed == response.pages {
						// There are no more pages.
						self.handleEndOfExecution()
					} else if self.sessionTasks.count == 0 {
						// If there are no more session tasks, and this code is running, we need still more photos.
						// This can happen if, for example, the same photo information existed in the first and
						// second pages of the results.
						self.getMoreResponsePages(searchResponse)
					}
				}
				self.sessionTasks[String(i)] = task
			}
		}
	}

	func addPhotosToContext(photos: [FlickrPhoto]) {
		for photo in photos {
			guard addPhoto(photo) else {
				// The maximum number of photos has been processed.  The operation has accomplished it's goal.
				handleEndOfExecution()
				return
			}
		}
	}

	/**
	Adds another photo to the context if the required number of photos has not yet been reached.

	This is a thread safe method.
	*/
	func addPhoto(photo: FlickrPhoto) -> Bool {
		var wasAdded = false
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		if photosAdded < maxPhotos {
			// TODO: first check if it exists in the managedObjectContext, before trying to add it.  Or use NSMergeByPropertyObjectTrumpMergePolicy, if possible.
			let context = pin.managedObjectContext!
			context.performBlockAndWait {
				let _ = Photo(pin: self.pin, photo: photo, order: self.photosAdded, managedObjectContext: context)
			}
			photosAdded += 1
			wasAdded = true
		}
		return wasAdded
	}

	func fetchResultsPage(page: Int, successHandler: (FlickrPhotoSearchResponse) -> Void) -> NSURLSessionDataTask {
		var latitude = 0.0
		var longitude = 0.0
		pin.managedObjectContext!.performBlockAndWait {
			latitude = self.pin.latitude
			longitude = self.pin.longitude
		}
		let task = client.searchLocation(page, latitude: latitude, longitude: longitude) { jsonObject, response, error in
			self.sessionTasks[String(page)] = nil

			guard !self.cancelled && self.error == nil else {
				return
			}

			if let err = error {
				self.error = self.makeNSError(ErrorCode.ErrorFetchingPhotoList.rawValue, localizedDescription: "Error fetching photo list", underlyingError: err)
				self.cancel()
				return
			}

			// If there was no error, WebClient has provided a response: 
			let httpResponse = response!

			guard httpResponse.statusCode == 200 else {
				self.error = self.makeNSError(ErrorCode.UnexpectedHTTPResponseCode.rawValue, localizedDescription: "Unexpected response code: \(httpResponse.statusCode)")
				self.cancel()
				return
			}

			guard let photosInfo = FlickrPhotoSearchResponse(jsonObject: jsonObject) else {
				self.error = self.makeNSError(ErrorCode.UnexpectedHTTPResponseFormat.rawValue, localizedDescription: "Unexpected response format")
				self.cancel()
				return
			}

			successHandler(photosInfo)
		}
		return task
	}

	override func cleanup() {
		print("In SearchOperation cleanup")  // TODO: remove
		if let err = error {
			pin.managedObjectContext?.performBlockAndWait {
				self.pin.photoProcessingError = err
				self.pin.photoProcessingState = Pin.PHOTO_PROCESSING_STATE_ERROR_WHILE_FETCHING_DATA
			}
		}
		persistData()
		super.cleanup()
	}

	func persistData() {

		guard let pinContext = pin.managedObjectContext else {
			error = makeNSError(ErrorCode.PinHasNoContext.rawValue, localizedDescription: "Data Storage error (pin is not associated with a context)")
			return
		}

		CoreDataStack.saveContext(pinContext, includeParentContexts: true) { error, isChildContext in
			guard let err = error else {
				return
			}

			if isChildContext {
				print("Error saving child context: \(err)")
				self.error = self.makeNSError(ErrorCode.SavingPinContextFailed.rawValue, localizedDescription: "Unable to stage photos data for saving", underlyingError: err)
			} else {
				print("Error saving parent context: \(err)")
				self.error = self.makeNSError(ErrorCode.SavingPinParentContextFailed.rawValue, localizedDescription: "Unable to persist photos data", underlyingError: err)
			}
		}
	}
}