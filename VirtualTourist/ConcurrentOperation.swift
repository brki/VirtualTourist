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
class ConcurrentOperation: ErrorAwareOperation {

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

	override func start() {
		preStartErrorAndCancellationCheck()

		guard !cancelled && error == nil else {
			handleEndOfExecution()
			return
		}

		executing = true
		startExecution()
	}

	/**
	Subclasses should override this to start whatever they want to start.
	*/
	func startExecution() {
	}

	override func cancel() {
		objc_sync_enter(self)
		super.cancel()
		handleEndOfExecution()
		objc_sync_exit(self)
	}

	func handleEndOfExecution() {
		objc_sync_enter(self)

		if !finished {

			cleanup()

			// Trigger KVO notifications:
			executing = false
			finished = true
		}
		objc_sync_exit(self)
	}

	/**
	Subclasses can override this to execute the necessary cleanup for when a task
	has finished (successfully or unsuccessfully, cancelled or not).
	*/
	func cleanup() {}
}
