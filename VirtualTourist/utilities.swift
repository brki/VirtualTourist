//
//  utilities.swift
//  VirtualTourist
//
//  Created by Brian King on 09/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit


func async_main(block: () -> Void) {
	dispatch_async(dispatch_get_main_queue(), block)
}


class Utility {

	static func presentAlert(title: String?, message: String?) {

		let alertController = UIAlertController(title: title, message: message, preferredStyle: .Alert)
		alertController.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))

		presentAlertControllerOnFrontController(alertController)
	}

	static func presentAlertControllerOnFrontController(alertController: UIAlertController) {
		async_main {
			guard var controller = UIApplication.sharedApplication().keyWindow?.rootViewController else {
				print("presentAlertControllerOnFrontController: Unable to get rootViewController")
				return
			}

			while let presentedController = controller.presentedViewController {
				controller = presentedController
			}

			// If view controller is being dismissed or presented, delay presentation a bit.
			if controller.isBeingDismissed() || controller.isBeingPresented() {
				dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC))), dispatch_get_main_queue()) {
					presentAlertControllerOnFrontController(alertController)
				}
				return
			}

			controller.presentViewController(alertController, animated: true, completion: nil)
		}
	}
}