//
//  ConcurrentDownloadOperation.swift
//  VirtualTourist
//
//  Created by Brian on 13/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

class ConcurrentDownloadOperation: ConcurrentOperation {

	// Holds reference to currently executing tasks
	var _sessionTasks = [String: NSURLSessionTask]()

	// Error handler closure that will be called if an error occurred during downloading.
	var downloadErrorHandler: ((NSError) -> Void)? = nil

	override init() {
		super.init()
		self.errorDomain = "ConcurrentDownloadOperation"
	}

	var maxConcurrency = 5
	lazy var concurrentQueue: NSOperationQueue = {
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = self.maxConcurrency
		return queue
	}()

	func addSessionTask(key: String, task: NSURLSessionTask) {
		objc_sync_enter(self)
		_sessionTasks[key] = task
		objc_sync_exit(self)
	}

	func removeSessionTask(key: String) {
		objc_sync_enter(self)
		_sessionTasks[key] = nil
		objc_sync_exit(self)
	}

	/**
	Ensure all sub-tasks are cancelled.
	*/
	override func cleanup() {
		for (key, task) in _sessionTasks {

			switch task.state {
			case .Running, .Suspended:
				task.cancel()
			default:
				break
			}

			_sessionTasks[key] = nil
		}

		concurrentQueue.cancelAllOperations()
		
		super.cleanup()
	}

	/**
	If there is an error, call the error handler with it.
	*/
	func callDownloadErrorHandler() {
		if let err = error {
			downloadErrorHandler?(err)
		}
	}


}
