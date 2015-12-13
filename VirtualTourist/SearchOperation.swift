//
//  SearchOperation.swift
//  VirtualTourist
//
//  Created by Brian on 09/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation
import CoreData

struct ErrorInfo {
	var title: String
	var message: String?
	var error: NSError?
}

class SearchOperation: NSOperation {
	var pin: Pin
	let client = FlickrClient.sharedClient
	var sessionTasks = [Int: NSURLSessionDataTask]()
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

	// If the operation finishes with an error, this value will be set.
	var error: NSError?

	override var asynchronous: Bool { return true }

	private var _executing : Bool = false
	override var executing : Bool {
		get { return _executing }
		set {
			willChangeValueForKey("isExecuting")
			_executing = newValue
			didChangeValueForKey("isExecuting")
		}
	}

	private var _finished : Bool = false
	override var finished : Bool {
		get { return _finished }
		set {
			willChangeValueForKey("isFinished")
			_finished = newValue
			didChangeValueForKey("isFinished")
		}
	}

	var maxConcurrency = 5
	lazy var concurrentQueue: NSOperationQueue = {
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = self.maxConcurrency
		return queue
	}()


	init(pin: Pin, maxPhotos: Int) {
		self.pin = pin
		self.maxPhotos = maxPhotos
		super.init()
	}

	override func start() {
		if cancelled {
			handleEndOfExecution()
			return
		}
		executing = true

		let firstPageTask = fetchResultsPage(1) { searchResponse in
			if self.cancelled {
				self.handleEndOfExecution()
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
		self.sessionTasks[1] = firstPageTask
	}

	func getMoreResponsePages(response: FlickrPhotoSearchResponse) {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		if self.cancelled {
			handleEndOfExecution()
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
				self.sessionTasks[i] = task
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

	func handleEndOfExecution() {
		// Cancel any oustanding NSURLSession tasks:
		if finished { return }
		cleanup()

		// Trigger KVO notifications:
		executing = false
		finished = true
	}

	/**
	Ensure all sub-tasks are cancelled.
	*/
	func cleanup() {
		for (key, task) in sessionTasks {

			switch task.state {
			case .Running, .Suspended:
				task.cancel()
			default:
				break
			}

			sessionTasks[key] = nil
		}
	}

	func cancelWithErrorInfo(err: ErrorInfo) {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		if cancelled {
			handleEndOfExecution()
			return
		}
		var description = err.title
		if let message = err.message {
			description += ": \(message)"
		}
		var userInfo: [String: AnyObject] = [NSLocalizedDescriptionKey: description]
		if let underlyingError = err.error {
			userInfo["UnderlyingError"] = underlyingError
		}
		error = NSError(domain: "SearchOperation", code: 1, userInfo: userInfo)
		cancel()
	}

	func fetchResultsPage(page: Int, successHandler: (FlickrPhotoSearchResponse) -> Void) -> NSURLSessionDataTask {
		var latitude = 0.0
		var longitude = 0.0
		pin.managedObjectContext!.performBlockAndWait {
			latitude = self.pin.latitude
			longitude = self.pin.longitude
		}
		let task = client.searchLocation(page, latitude: latitude, longitude: longitude) { jsonObject, response, error in
			self.sessionTasks[page] = nil
			if self.cancelled {
				self.handleEndOfExecution()
				return
			}
			if let err = error {
				self.cancelWithErrorInfo(ErrorInfo(title: "Error fetching photo list", message: err.localizedDescription, error: err))
				return
			}
			guard let httpResponse = response as? NSHTTPURLResponse else {
				self.cancelWithErrorInfo(ErrorInfo(title: "Unexpected response type", message: "response: \(response)", error: nil))
				return
			}
			guard httpResponse.statusCode == 200 else {
				self.cancelWithErrorInfo(ErrorInfo(title: "Unexpected response", message: "Code: \(httpResponse.statusCode)", error: nil))
				return
			}
			guard let photosInfo = FlickrPhotoSearchResponse(jsonObject: jsonObject) else {
				self.cancelWithErrorInfo(ErrorInfo(title: "Unexpected response format", message: nil, error: nil))
				return
			}

			successHandler(photosInfo)
		}
		return task
	}
}