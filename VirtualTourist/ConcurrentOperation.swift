//
//  ConcurrentDownloadOperation.swift
//  VirtualTourist
//
//  Created by Brian on 13/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

/**
An operation whose prinicpal task runs asynchronously.

Since it runs asynchronously, subclasses should implement start(), not main().
*/
class ConcurrentOperation: NSOperation {

	struct ErrorInfo {
		var title: String
		var message: String?
		var error: NSError?
	}

	var errorDomain: String = "ConcurrentOperation"

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

	override init() {
		super.init()
	}

	override func cancel() {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		handleEndOfExecution()
		super.cancel()
	}

	// TODO: rename this:
	func handleEndOfExecution() {
		if finished { return }
		cleanup()

		// Trigger KVO notifications:
		executing = false
		finished = true
	}

	// TODO: rename this:
	/**
	Subclasses can override this to execute the necessary cleanup for when a task
	has finished (successfully or unsuccessfully, cancelled or not).
	*/
	func cleanup() {}

	func makeNSError(code: Int, localizedDescription: String, underlyingError: NSError? = nil ) -> NSError {
		var userInfo: [String: AnyObject] = [NSLocalizedDescriptionKey: localizedDescription]
		if let error = underlyingError {
			userInfo["underlyingError"] = error
		}
		return NSError(domain: errorDomain, code: code, userInfo: userInfo)
	}
}
