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
	var sessionTasks = [String: NSURLSessionTask]()

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

	/**
	Ensure all sub-tasks are cancelled.
	*/
	override func cleanup() {
		for (key, task) in sessionTasks {

			switch task.state {
			case .Running, .Suspended:
				task.cancel()
			default:
				break
			}

			sessionTasks[key] = nil
		}

		concurrentQueue.cancelAllOperations()
		
		super.cleanup()
	}
}
