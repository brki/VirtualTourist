//
//  DownloadSingleFileOperation.swift
//  VirtualTourist
//
//  Created by Brian on 15/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

class DownloadSingleFileOperation: ConcurrentOperation {

	enum ErrorCode: Int {
		case ErrorFetchingFile = 1
		case UnexpectedHTTPResponseCode = 2
	}

	var url: NSURL
	var handler: ((NSData?, NSError?) -> Void)?
	var task: NSURLSessionDataTask?
	var data: NSData?

	init(url: NSURL, handler: ((NSData?, NSError?) -> Void)?) {
		self.url = url
		self.handler = handler
		super.init()
		self.errorDomain = "DownloadSingleFileOperation"
	}

	override func startExecution() {
		initiateDownload()
	}

	func initiateDownload() {
		let request = NSURLRequest(URL: self.url)
		task = WebClient.dataRequest(request) { data, response, error in

			self.task = nil

			if self.cancelled {
				return
			}

			if let err = error {

				// If the error is a NSURLErrorDomain error, use it's description, otherwise use something generic.
				var errorDescription = "Error fetching file"
				if err.domain == "NSURLErrorDomain" {
					errorDescription = err.localizedDescription
				}

				self.error = self.makeNSError(ErrorCode.ErrorFetchingFile.rawValue, localizedDescription: errorDescription, underlyingError: err)

			} else {

				// If there was no error, WebClient has provided a response:
				let httpResponse = response!

				if httpResponse.statusCode == 200 {
					self.data = data
				} else {
					let description = "Unexpected response code: \(httpResponse.statusCode)"
					self.error = self.makeNSError(ErrorCode.UnexpectedHTTPResponseCode.rawValue, localizedDescription: description, userInfo: ["errorCode": httpResponse.statusCode])
				}

			}

			self.handleEndOfExecution()
		}
		task!.resume()
	}

	override func cleanup() {
		// Cancel the task, if it is executing:
		self.task?.cancel()

		// Call the operation handler, unless the operation was cancelled:
		if !cancelled {
			handler?(data, error)
		}

		// Free up data and the task memory, since the operation may sit around in a queue for a while:
		data = nil
		error = nil
		super.cleanup()
	}
}