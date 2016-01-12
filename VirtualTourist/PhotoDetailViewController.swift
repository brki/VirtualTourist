//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Brian on 11/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import UIKit
import AVFoundation

class PhotoDetailViewController: UIViewController {

	var thumbnailImage: UIImage!
	var photo: Photo!
	var isFullScreen = false

	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var imageView: UIImageView!
	@IBOutlet weak var scrollViewCenterYToSuperviewCenterY: NSLayoutConstraint!

	override func viewDidLoad() {
		super.viewDidLoad()
		scrollView.delegate = self
		imageView.image = thumbnailImage
		addDownloadOperation()
	}

	func showFullScreen(fullScreen: Bool) {
		isFullScreen = fullScreen
		let app = UIApplication.sharedApplication()
		let navController = navigationController!
		navController.navigationBarHidden = fullScreen
		app.statusBarHidden = fullScreen
		scrollView.contentSize = imageView.frame.size

		let verticalAdjustment = (navController.navigationBar.frame.height + app.statusBarFrame.height) / 2
		if fullScreen {
			scrollViewCenterYToSuperviewCenterY.constant = 0
//			scrollView.contentSize.height -= verticalAdjustment
		} else {
			scrollViewCenterYToSuperviewCenterY.constant = -verticalAdjustment
//			scrollView.contentSize.height += verticalAdjustment
		}
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		scrollView.contentSize = imageView.image!.size
		configureZooming()
		print("imageView: \(imageView.frame.size)")
		print("image: \(imageView.image!.size)")
//		scrollView.contentSize = imageView.frame.size
//		showFullScreen(false)
//		scrollViewCenterYToSuperviewCenterY.constant = -100
//		let verticalMargin = (scrollView.frame.size.height - imageView.frame.size.height) / 2.0
//		let horizontalMargin = (scrollView.frame.size.width - imageView.frame.size.width) / 2.0
//		scrollView.contentInset = UIEdgeInsets(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin)
	}

	override func viewWillDisappear(animated: Bool) {
		navigationController?.navigationBarHidden = false
		UIApplication.sharedApplication().statusBarHidden = false
	}

	func configureZooming() {
		scrollView.minimumZoomScale = 1.0
		scrollView.maximumZoomScale = 4.0
		setMinimumZoomScale()
	}

	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		print("ho")
	}

	func setMinimumZoomScale() {
		var zoomScale = min(view.bounds.size.width / imageView.image!.size.width, view.bounds.size.height / imageView.image!.size.height)

		if (zoomScale > 1) {
			zoomScale = 1;
		}
		print("zoomScale: \(zoomScale)")
		self.scrollView.minimumZoomScale = zoomScale;
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
				self.imageView.sizeToFit()
//				let rect = AVMakeRectWithAspectRatioInsideRect(self.imageView.image!.size, self.imageView.bounds)
//
//				self.scrollView.contentSize = CGSizeMake(rect.width / 4, rect.height / 4)
//				self.setMinimumZoomScale()
				print("imageView: \(self.imageView.frame.size)")
				print("image: \(self.imageView.image!.size)")

//				self.scrollView.contentSize = self.imageView.frame.size
			}
		}
		operation.queuePriority = .VeryHigh
		QueueManager.filesDownloadQueue.addOperation(operation)
	}

	/**
	Hide / show the navigation and status bar in response to a single tap.
	*/
	@IBAction func imageViewTapped(sender: UITapGestureRecognizer) {
		showFullScreen(!isFullScreen)
//		if let navController = navigationController {
//			navController.navigationBarHidden = !navController.navigationBarHidden
//		}
//		let app = UIApplication.sharedApplication()
//		app.statusBarHidden = !app.statusBarHidden
////		scrollView.contentSize = imageView.frame.size
	}
}

extension PhotoDetailViewController: UIScrollViewDelegate {
	func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
		return imageView
	}

//	func scrollViewDidZoom(scrollView: UIScrollView) {
//		let offsetX = (scrollView.bounds.size.width > scrollView.contentSize.width) ? (scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5 : 0.0;
//
//		let offsetY = (scrollView.bounds.size.height > scrollView.contentSize.height) ? (scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5 : 0.0;
//
//		imageView.center = CGPointMake(scrollView.contentSize.width * 0.5 + offsetX,
//		scrollView.contentSize.height * 0.5 + offsetY);
//		print("scrollView zoom: \(scrollView.zoomScale), content size: \(scrollView.contentSize)")
//	}
//
//	func scrollViewDidZoom(scrollView: UIScrollView) {
//		let imageViewFrameSize = imageView.frame.size
//		let imageSize = self.imageView.image!.size
//
//		var realImageSize: CGSize
//		if imageSize.width / imageSize.height > imageViewFrameSize.width / imageSize.height {
//			realImageSize = CGSize(width: imageViewFrameSize.width, height: imageViewFrameSize.width / imageSize.width * imageSize.height)
//		} else {
//			realImageSize = CGSize(width: imageViewFrameSize.height / imageSize.height * imageSize.width, height: imageViewFrameSize.height)
//		}
//
//		self.imageView.frame = CGRect(origin: CGPointZero, size: realImageSize)
//
//		let scrollViewSize = scrollView.frame.size
//		let marginX = scrollViewSize.width > realImageSize.width ? (scrollViewSize.width - realImageSize.width) / 2 : 0
//		let marginY = scrollViewSize.height > realImageSize.height ? (scrollViewSize.height - realImageSize.height) / 2 : 0
//
//		scrollView.contentInset = UIEdgeInsetsMake(marginY, marginX, marginY, marginX)
//	}
//	-(void)scrollViewDidZoom:(UIScrollView *)scrollView
//	{
//	CGSize imgViewSize = self.imageView.frame.size;
//	CGSize imageSize = self.imageView.image.size;
//
//	CGSize realImgSize;
//	if(imageSize.width / imageSize.height > imgViewSize.width / imgViewSize.height) {
//	realImgSize = CGSizeMake(imgViewSize.width, imgViewSize.width / imageSize.width * imageSize.height);
//	}
//	else {
//	realImgSize = CGSizeMake(imgViewSize.height / imageSize.height * imageSize.width, imgViewSize.height);
//	}
//
//	CGRect fr = CGRectMake(0, 0, 0, 0);
//	fr.size = realImgSize;
//	self.imageView.frame = fr;
//
//	CGSize scrSize = scrollView.frame.size;
//	float offx = (scrSize.width > realImgSize.width ? (scrSize.width - realImgSize.width) / 2 : 0);
//	float offy = (scrSize.height > realImgSize.height ? (scrSize.height - realImgSize.height) / 2 : 0);
//
//	// don't animate the change.
//	scrollView.contentInset = UIEdgeInsetsMake(offy, offx, offy, offx);
//	}
}