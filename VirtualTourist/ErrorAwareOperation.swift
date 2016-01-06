//
//  ErrorAwareOperation.swift
//  VirtualTourist
//
//  Created by Brian on 25/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

class ErrorAwareOperation: NSOperation {

	// If the operation finishes with an error, this value will be set.
	var error: NSError?
	var errorDomain: String = "ErrorAwareOperation"

	// Error handler that will be typically be called in the operation's cleanup() method.
	var errorHandler: ((NSError) -> Void)? = nil

	var shouldCancelIfAnyDependencyCancelled = true
	var shoudSetErrorIfAnyDependencyHasError = true
	var shouldCancelBeforeStartingIfErrorSet = true

	/**
	If any of the tasks that this operation depend on were cancelled, and shouldCancelIfAnyDependencyCancelled is true,
	then cancel this task.
	*/
	func cancelIfAnyDependencyCancelled() {
		guard shouldCancelIfAnyDependencyCancelled else {
			return
		}
		for dependency in self.dependencies {
			if dependency.cancelled {
				self.cancel()
				return
			}
		}
	}

	/**
	If any of the tasks that this operation depend on have an error, and shouldEndWithErrorIfAnyDependencyHasError is true,
	then set this operation's error to the first dependency error that is encountered.
	*/
	func setErrorIfAnyDependencyHasError() {
		guard shoudSetErrorIfAnyDependencyHasError else {
			return
		}
		for dependency in self.dependencies {
			if let d = dependency as? ErrorAwareOperation,
				err = d.error {
					error = err
			}
		}
	}

	func makeNSError(code: Int, localizedDescription: String, underlyingError: NSError? = nil ) -> NSError {
		var userInfo: [NSObject: AnyObject] = [NSLocalizedDescriptionKey: localizedDescription]
		if let error = underlyingError {
			userInfo["underlyingError"] = error
		}
		return NSError(domain: errorDomain, code: code, userInfo: userInfo)
	}

	/**
	If any dependency has cancelled, also cancel this operation (unless shouldCancelIfAnyDependencyCancelled is false).

	If any dependency has set an error, assign the first error encountered to self.error (unless shoudSetErrorIfAnyDependencyHasError is false).

	If self.error is set, cancel this operation (unless shouldCancelBeforeStartingIfErrorSet is false).
	*/
	func preStartErrorAndCancellationCheck() {
		setErrorIfAnyDependencyHasError()
		cancelIfAnyDependencyCancelled()
		if error != nil && shouldCancelBeforeStartingIfErrorSet {
			self.cancel()
		}
	}

	/**
	If there is an error, call the error handler with it.
	*/
	func callErrorHandler() {
		if let err = error {
			errorHandler?(err)
		}
	}

}