//
//  OperationMap.swift
//  VirtualTourist
//
//  Created by Brian on 12/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

enum OperationType {
	case Search
}

/**
Maintains queues used by this app:
- a serial operation queue for each Pin, if one is needed
- a concurrent queue for DownloadFileOperations
- a serial queue for file operations
*/
struct QueueManager {

	static var filesDownloadQueue: NSOperationQueue = {
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 2
		return queue
	}()

	static var fileOperationsQueue: NSOperationQueue = {
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 1
		return queue
	}()

	static var queues = [Pin: NSOperationQueue]()

	static func serialQueueForPin(pin: Pin) -> NSOperationQueue {
		if let queue = queues[pin] {
			return queue
		}

		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 1
		queues[pin] = queue
		return queue
	}

	static func removeSerialQueueForPin(pin: Pin) {
		if let queue = queues[pin] {
			guard queue.operationCount == 0 else {
				print("Warning: tried to remove serial queue for pin\(pin), but the queue is not empty")
				return
			}
			queues[pin] = nil
		}
	}
}