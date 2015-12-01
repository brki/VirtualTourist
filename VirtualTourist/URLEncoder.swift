//
//  URLEncoder.swift
//  OnTheMap
//
//  Created by Brian on 24/09/15.
//  Copyright © 2015 truckin'. All rights reserved.
//

import Foundation

class URLEncoder {
	static let sharedInstance = URLEncoder()

	/**
	Character set containing all characters allowed in a path compent (e.g. between two '/' characters in a URL's path).

	This is NSCharacterSet.URLPathAllowedCharacterSet() minus the '/' character.
	*/
	lazy var pathComponentAllowedCharacterSet: NSCharacterSet = {
		let pathCharacterSet = NSCharacterSet.URLPathAllowedCharacterSet().mutableCopy() as! NSMutableCharacterSet
		pathCharacterSet.removeCharactersInString("/")
		return pathCharacterSet
		}()

	/**
	Generates a query string with an optional leading '?' character from the provided param dictionary.
	*/
	func encodedQueryStringFromParams(params: [String: String], includingLeadingQueryIndicator: Bool = true) -> String? {
		if params.count == 0 {
			return ""
		}
		let queryItems = params.map { NSURLQueryItem(name:$0, value:$1) }
		let components = NSURLComponents()
		components.queryItems = queryItems
		let queryString = components.percentEncodedQuery
		if let qs = queryString {
			if includingLeadingQueryIndicator {
				return "?\(qs)"
			}
			return qs
		}
		return nil
	}

	/**
	Encodes the provided String as a path component (the text between two '/' characters in a URL's path).
	*/
	func encodedPathComponent(pathComponent: String) -> String? {
		return pathComponent.stringByAddingPercentEncodingWithAllowedCharacters(pathComponentAllowedCharacterSet)
	}

	/**
	Replaces placeholders in the given String with path-component encoded values, provided
	that the params has the placeholders as keys and replacement texts as values.

	For example, ``stringWithPathEncodedReplacements("/foo/{1}/bar", params: ["{1}": "buzz buzz")
	will result in
	``/foo/buzz%20buzz/bar``
	*/
	func pathWithEncodedReplacements(var path: String, params: [String: String]) -> String {
		for (key, value) in params {
			path = path.stringByReplacingOccurrencesOfString(key, withString: encodedPathComponent(value)!)
		}
		return path
	}
}