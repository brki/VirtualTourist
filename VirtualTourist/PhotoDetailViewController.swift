//
//  PhotoDetailViewController.swift
//  VirtualTourist
//
//  Created by Brian on 11/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import UIKit

/**
A zoomable detail view.

I struggled for quite a while trying to have the image zooming and panning 
behaving nicely on my own; apparently I'm not the only one to have had
problems with this, judging from Stackoverflow.

This pure auto-layout solution, which updates constraint constants in the code,
is based on https://github.com/evgenyneu/ios-imagescroll-swift .  It has beenn
adapted so that it also plays nicely when showing / hiding the navigation and
status bars.
*/
class PhotoDetailViewController: UIViewController {

	var thumbnailImage: UIImage!
	var photo: Photo!
	var lastZoomScale: CGFloat = 0.0
	var originalNavbarTranslucent: Bool?

	@IBOutlet var scrollView: UIScrollView!
	@IBOutlet var imageView: UIImageView!
	@IBOutlet weak var imageConstraintLeft: NSLayoutConstraint!
	@IBOutlet weak var imageConstraintRight: NSLayoutConstraint!
	@IBOutlet weak var imageConstraintBottom: NSLayoutConstraint!
	@IBOutlet weak var imageConstraintTop: NSLayoutConstraint!
	@IBOutlet weak var imageCenterXConstraint: NSLayoutConstraint!
	@IBOutlet weak var imageCenterYConstraint: NSLayoutConstraint!

	override func viewDidLoad() {
		super.viewDidLoad()
		if let navBar = navigationController?.navigationBar {
			originalNavbarTranslucent = navBar.translucent
			navBar.translucent = false
		}

		scrollView.delegate = self
		scrollView.maximumZoomScale = 4.0
		addDownloadOperation()
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if imageView.image == nil {
			imageView.image = thumbnailImage
			scrollView.zoomScale = 1.0
		}
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidDisappear(animated)
	}

	override func viewWillDisappear(animated: Bool) {
		if let navBar = navigationController?.navigationBar {
			navBar.hidden = false
			navBar.translucent = originalNavbarTranslucent!
		}
		UIApplication.sharedApplication().statusBarHidden = false
	}

	/**
	Hide / show the navigation and status bar in response to a single tap.
	*/
	@IBAction func imageViewTapped(sender: UITapGestureRecognizer) {
		toggleFullScreen()
	}

	func toggleFullScreen() {
		let app = UIApplication.sharedApplication()
		let navController = navigationController!
		let hidden = !navController.navigationBarHidden
		navController.navigationBarHidden = hidden
		app.statusBarHidden = hidden
		updateZoom()
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
				self.imageCenterXConstraint.priority = 0.1
				self.imageCenterYConstraint.priority = 0.1
				self.updateZoom()
			}
		}
		operation.queuePriority = .VeryHigh
		QueueManager.filesDownloadQueue.addOperation(operation)
	}

	// MARK: Zoom adjustments

	/**
	When the view size changes, adjust the zoom, which will trigger an update of the constraints.
	*/
	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)

		coordinator.animateAlongsideTransition(
			{ [weak self] _ in
				self?.updateZoom()
			},
			completion: nil
		)
	}

	func updateConstraints() {
		print("updateConstraints...")
		if let image = imageView.image {
			let imageWidth = image.size.width
			let imageHeight = image.size.height

			let viewWidth = scrollView.bounds.size.width
			let viewHeight = scrollView.bounds.size.height

			// center image if it is smaller than the scroll view
			var hPadding = (viewWidth - scrollView.zoomScale * imageWidth) / 2
			if hPadding < 0 {
				hPadding = 0
			}

			var vPadding = (viewHeight - scrollView.zoomScale * imageHeight) / 2
			if vPadding < 0 {
				vPadding = 0
			}

			imageConstraintLeft.constant = hPadding
			imageConstraintRight.constant = hPadding

			imageConstraintTop.constant = vPadding
			imageConstraintBottom.constant = vPadding

			view.layoutIfNeeded()
		}
	}

	// Zoom to show as much image as possible unless image is smaller than the scroll view
	private func updateZoom() {
		if let image = imageView.image {
			var minZoom = min(scrollView.bounds.size.width / image.size.width, scrollView.bounds.size.height / image.size.height)

			if minZoom > 1 { minZoom = 1 }

			scrollView.minimumZoomScale = minZoom

			// Force scrollViewDidZoom fire if zoom did not change
			if minZoom == lastZoomScale { minZoom += 0.000001 }

			scrollView.zoomScale = minZoom
			lastZoomScale = minZoom
		}
	}
}


// MARK: UIScrollViewDelegate

extension PhotoDetailViewController: UIScrollViewDelegate {
	func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
		return imageView
	}

	func scrollViewDidZoom(scrollView: UIScrollView) {
		updateConstraints()
	}
}