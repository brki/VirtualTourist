//
//  utilities.swift
//  VirtualTourist
//
//  Created by Brian King on 09/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

func async_main(block: () -> Void) {
	dispatch_async(dispatch_get_main_queue(), block)
}
