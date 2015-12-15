//
//  DownloadSingleFileOperation.swift
//  VirtualTourist
//
//  Created by Brian on 15/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

class DownloadSingleFileOperation: ConcurrentOperation {

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

	override func start() {
		if cancelled {
			handleEndOfExecution()
			return
		}
		executing = true

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

				self.error = self.makeNSError(1, localizedDescription: "Error fetching file", underlyingError: err)

			} else {

				// If there was no error, WebClient has provided a response:
				let httpResponse = response!

				if httpResponse.statusCode == 200 {
					self.data = data
				} else {
					self.error = self.makeNSError(2, localizedDescription: "Unexpected response code: \(httpResponse.statusCode)")
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