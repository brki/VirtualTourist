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
Maintains a serial operation queue for each Pin, if one is needed.
*/
struct QueueManager {

	static var filesDownloadQueue: NSOperationQueue = {
		let queue = NSOperationQueue()
		queue.maxConcurrentOperationCount = 2
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

	// TODO: cancel all operations in queue and remove queue if pin is removed.

	static func removeSerialQueueForPin(pin: Pin) {
		queues[pin] = nil
	}

}