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

		guard var controller = UIApplication.sharedApplication().keyWindow?.rootViewController else {
			print("presentAlert: Unable to get rootViewController")
			return
		}

		while let presentedController = controller.presentedViewController {
			controller = presentedController
		}

		controller.presentViewController(alertController, animated: true, completion: nil)
	}
}