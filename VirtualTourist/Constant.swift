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

	// Flickr default per_page value is 250.  Set to a low value so that
	// the fetch-multiple-pages-of-results logic gets used, and so that there
	// are not too many photos for each collection view:
	static let photosPerPage = 5

	static let maxFlickrGeoQueryResults = 4000

	static let documentDir = try! NSFileManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
}