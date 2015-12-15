//
//  FlickrObjects.swift
//  VirtualTourist
//
//  Created by Brian King on 09/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation


struct FlickrPhotoSearchResponse {
	let photos: [FlickrPhoto]
	let page: Int
	let pages: Int
	let perpage: Int
	let total: Int

	init?(jsonObject: AnyObject?) {
		func intValFromExpectedString(string: AnyObject?) -> Int? {
			guard let stringVal = string as? String,
				intVal = Int(stringVal) else {
					return nil
			}
			return intVal
		}

		guard let json = jsonObject as? [String: AnyObject],
			photos = json["photos"] as? [String: AnyObject],
			page = photos["page"] as? Int,
			perpage = photos["perpage"] as? Int,
			pages = photos["pages"] as? Int,
			total = intValFromExpectedString(photos["total"]),
			photoArray = photos["photo"] as? [[String: AnyObject]] else {
				print("FlickPhotoSearchResponse: unexpected format 1")
				return nil
		}
		self.page = page
		self.pages = pages
		self.total = total
		self.perpage = perpage
		var photoList = [FlickrPhoto]()
		for photoInfo in photoArray {
			photoList.append(FlickrPhoto(json: photoInfo))
		}
		self.photos = photoList
	}

}

struct FlickrPhoto {
	let id: String
	let title: String?
	let urlTemplate: String

	init(json: [String: AnyObject]) {

		/**
		Returns a string template with a {size} component that can be replaced with
		one of the valid Flickr size prefixes.

		See https://www.flickr.com/services/api/misc.urls.html for available size prefixes.
		*/
		func URLTemplate(json: [String: AnyObject]) -> String {
			return "https://farm\(json["farm"]!).staticflickr.com/\(json["server"]!)/\(json["id"]!)_\(json["secret"]!)_{size}.jpg"
		}

		self.id = json["id"] as! String
		self.title = json["title"] as? String
		self.urlTemplate = URLTemplate(json)
	}
}