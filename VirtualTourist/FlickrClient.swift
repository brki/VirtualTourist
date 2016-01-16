//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by Brian on 01/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

class FlickrClient: WebClient {

	static let sharedClient = FlickrClient(baseURL: "https://api.flickr.com/services/")!

	let API_KEY = "d6be7f27a3738a46448ff1c2638b62af"
	let radiusMinutes = 1.25  // Approximately 2.3 km search radius.
	lazy var defaultParams: [String: String] = {
		return [
			"method": "flickr.photos.search",
			"api_key": self.API_KEY,
			"format": "json",
			"nojsoncallback": "1",
			"media": "photos",
			"content_type": "1",  // photos only, not screenshots
			"sort": "date-taken-desc",
			"extras": "date_taken",
		]
	}()

	func searchLocation(page: Int, latitude: Double, longitude: Double, perPage: Int, handler: ((jsonObject: AnyObject?, response: NSHTTPURLResponse?, error: NSError?) -> Void)? = nil) -> NSURLSessionDataTask {

		let requestParams = defaultParams + [
			"page": String(page),
			"per_page": String(perPage),
			"bbox": boundingBox(latitude: latitude, longitude: longitude, minutes: radiusMinutes)
		]

		let url = router.url(Path.RESTAPI, queryParams: requestParams)!
		return makeJSONDataRequest(url, requestMethod: .GET, completionHandler: handler)
	}

	/**
	Get a bounding box around the given position.
	1 minute is approximately 1.85 kilometers.
	*/
	func boundingBox(latitude latitude: Double, longitude: Double, minutes: Double = 5) -> String {
		let offset = minutes / 60
		let minLatitude = wrapLatitude(latitude - offset)
		let maxLatitude = wrapLatitude(latitude + offset)
		let minLongitude = wrapLongitude(longitude - offset)
		let maxLongitude = wrapLongitude(longitude + offset)
		return "\(minLongitude),\(minLatitude),\(maxLongitude),\(maxLatitude)"
	}

	func wrapLatitude(value: Double) -> Double {
		if value < -90 || value > 90 {
			return atan(sin(value) / abs(cos(value)))
		}
		return value
	}

	func wrapLongitude(value: Double) -> Double {
		if value < -180 || value > 180 {
			return atan2(sin(value), cos(value))
		}
		return value
	}

	// MARK: PathComponentProviding definitions

	// This is necessary for the Webclient.router.url() method:
	enum Path: String, PathComponentProviding {
		case RESTAPI = "rest/"
		func pathComponent() -> String {
			return self.rawValue
		}
	}
}