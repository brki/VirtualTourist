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
	var maxPages: Int
	var startPage: Int!
	var endPage: Int!
	var neededPages: Int!
	var perPage: Int
	var latitude: Double!
	var longitude: Double!

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
	var _highestProcessedPage = 0

	// Thread safe, only accepts new value if it is greater than the previously set value:
	var highestProcessedPage: Int {
		get {
			return _highestProcessedPage
		}
		set {
			objc_sync_enter(self)
			if newValue > _highestProcessedPage {
				_highestProcessedPage = newValue
			}
			objc_sync_exit(self)
		}
	}


	init(pin: Pin, maxPages: Int, perPage: Int) {
		self.pin = pin
		self.maxPages = maxPages
		self.perPage = perPage
		super.init()
		pin.managedObjectContext!.performBlockAndWait {
			self.latitude = pin.latitude
			self.longitude = pin.longitude
			self.startPage = pin.lastPhotoPageProcessed + 1
		}
		self.errorDomain = "SearchOperation"
	}

	override func startExecution() {
		let firstPageTask = fetchResultsPage(1) { searchResponse in
			if self.cancelled {
				return
			}
			guard searchResponse.total > 0 else {
				// There are no photos
				self.handleEndOfExecution()
				return
			}

			// If a new collection has been requested, but there are no more available pages,
			// or if the geo-query maximum limit has been reached, wrap back around to page 1.
			if searchResponse.pages < self.startPage || (self.startPage - 1) * self.perPage >= Constant.maxFlickrGeoQueryResults {
				self.startPage = 1
			}

			self.endPage = min(searchResponse.pages, self.startPage + self.maxPages - 1)
			self.neededPages = self.endPage - self.startPage + 1
			self.getMoreResponsePages(searchResponse)
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

		for page in startPage ... endPage {
			// Launch more URLSessionTasks using a concurrent queue.
			self.concurrentQueue.addOperationWithBlock {
				let task = self.fetchResultsPage(page) { searchResponse in

					guard !self.cancelled && self.error == nil else {
						return
					}

					self.addPhotosToContext(searchResponse.photos)
					self.pagesProcessed += 1
					self.highestProcessedPage = page

					if self.pagesProcessed == self.neededPages {
						self.handleEndOfExecution()
					}
				}
				self.sessionTasks[String(page)] = task
			}
		}
	}

	func addPhotosToContext(photos: [FlickrPhoto]) {
		for photo in photos {
			addPhoto(photo)
		}
	}

	/**
	Adds another photo to the context if the required number of photos has not yet been reached.

	This is a thread safe method.
	*/
	func addPhoto(photo: FlickrPhoto) {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		let context = pin.managedObjectContext!
		context.performBlockAndWait {
			let _ = Photo(pin: self.pin, photo: photo, order: self.photosAdded, managedObjectContext: context)
		}
		photosAdded += 1
	}

	func fetchResultsPage(page: Int, successHandler: (FlickrPhotoSearchResponse) -> Void) -> NSURLSessionDataTask {
		let task = client.searchLocation(page, latitude: latitude, longitude: longitude, perPage: perPage) { jsonObject, response, error in
			self.sessionTasks[String(page)] = nil

			guard !self.cancelled && self.error == nil else {
				return
			}

			if let err = error {

				// If the error is a NSURLErrorDomain error, use it's description, otherwise use something generic.
				var errorDescription = "Error fetching photo list"
				if err.domain == "NSURLErrorDomain" {
					errorDescription = err.localizedDescription
				}

				self.error = self.makeNSError(ErrorCode.ErrorFetchingPhotoList.rawValue, localizedDescription: errorDescription, underlyingError: err)
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
		callDownloadErrorHandler()
		persistData()
		super.cleanup()
	}

	func persistData() {

		guard let pinContext = pin.managedObjectContext else {
			error = makeNSError(ErrorCode.PinHasNoContext.rawValue, localizedDescription: "Data Storage error (pin is not associated with a context)")
			return
		}

		pinContext.performBlock {
			self.pin.lastPhotoPageProcessed = self.highestProcessedPage
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