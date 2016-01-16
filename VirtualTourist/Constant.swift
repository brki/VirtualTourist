//
//  Constant.swift
//  VirtualTourist
//
//  Created by Brian on 12/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

struct Constant {
	static let maxPhotoPagesPerCollection = 3
	static let photosPerPage = 3
	static let documentDir = try! NSFileManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
}