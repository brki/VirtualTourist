//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Brian on 11/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import UIKit

class PhotoDetailViewController: UIViewController {

	var thumbnailImage: UIImage!
	var photo: Photo!

	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var imageView: UIImageView!

	override func viewDidLoad() {
		super.viewDidLoad()
		scrollView.delegate = self
		configureZooming()
		imageView.image = thumbnailImage
		addDownloadOperation()
	}

	override func viewWillDisappear(animated: Bool) {
		navigationController?.navigationBarHidden = false
	}

	func configureZooming() {
		scrollView.minimumZoomScale = 1.0
		scrollView.maximumZoomScale = 4.0
	}

	func addDownloadOperation() {
		let operation = DownloadSingleFileOperation(url: photo.URLForSize(.Large1024)) { data, error in
			guard let controller = self.navigationController?.visibleViewController as? PhotoDetailViewController where controller == self else {
				// This view controller is not currently being displayed.
				return
			}
			guard error == nil else {
				print("PhotoDetailViewController.addDownloadOpoeration handler: error returned: \(error)")
				return
			}
			guard let imageData = data, image = UIImage(data: imageData) else {
				print("PhotoDetailViewController.addDownloadOpoeration handler: unable to create image from data.")
				return
			}
			async_main {
				self.imageView.image = image
			}
		}
		operation.queuePriority = .VeryHigh
		QueueManager.filesDownloadQueue.addOperation(operation)
	}
	
	@IBAction func imageViewTapped(sender: UITapGestureRecognizer) {
		if let navController = navigationController {
			navController.navigationBarHidden = !navController.navigationBarHidden
		}
	}
}

extension PhotoDetailViewController: UIScrollViewDelegate {
	func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
		return imageView
	}
}