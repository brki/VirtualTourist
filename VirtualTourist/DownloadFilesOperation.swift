//
//  DownloadFilesOperation.swift
//  VirtualTourist
//
//  Created by Brian on 13/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

import Foundation
import CoreData

class DownloadFilesOperation: ConcurrentDownloadOperation {

	let client = FlickrClient.sharedClient
	let photos: [Photo]!
	var photoSize: Photo.PhotoSize!

	init(photos: [Photo], photoSize: Photo.PhotoSize = .Medium) {
		self.photos = photos
		self.photoSize = photoSize
		super.init()
	}

	override func start() {
		if cancelled {
			return
		}
		executing = true

		for photo in photos {
			var photoAlreadyDownloaded = false
			var photoID: String!
			var url: NSURL!
			var saveToFileURL: NSURL?

			photo.managedObjectContext!.performBlockAndWait {
				photoAlreadyDownloaded = photo.downloaded
				url = photo.URLForSize(self.photoSize)
				photoID = photo.flickrID
				saveToFileURL = photo.fileURL
			}

			guard !photoAlreadyDownloaded else {
				continue
			}

			guard let fileURL = saveToFileURL else {
				self.error = self.makeNSError(1, localizedDescription: "Unable to get file saving path for photo with id \(photoID)")
				self.handleEndOfExecution()
				return
			}

			let operation = DownloadSingleFileOperation(url: url) { data, error in

				if self.cancelled {
					return
				}

				if let err = error {
					self.error = err
					self.handleEndOfExecution()
					return
				}

				guard let fileData = data else {
					self.error = self.makeNSError(2, localizedDescription: "No data returned, no error information available")
					self.handleEndOfExecution()
					return
				}

				fileData.writeToURL(fileURL, atomically: true)

				// Update the photo record with the fact that it has been downloaded.
				// This will send a notification, so interested parties can observe this change.
				photo.managedObjectContext?.performBlock {
					photo.downloaded = true
				}
			}

			concurrentQueue.addOperation(operation)
		}
	}

	override func cleanup() {
		concurrentQueue.cancelAllOperations()
		super.cleanup()
	}
}