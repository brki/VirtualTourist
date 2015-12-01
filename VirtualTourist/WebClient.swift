//
//  WebClient.swift
//  OnTheMap
//
//  Created by Brian on 29/09/15.
//  Copyright © 2015 truckin'. All rights reserved.
//

import Foundation

class WebClient {
	enum MethodType: String {
		case POST = "POST", GET = "GET", DELETE = "DELETE", PUT = "PUT"
	}

	let router: WebClientRouter!

	init?(baseURL: String) {
		router = WebClientRouter(baseURL: baseURL)
		if router == nil {
			return nil
		}
	}

	/**
	Start a NSURLSession data task.
	*/
	func makeDataRequest(url: NSURL, requestMethod: MethodType, let headers: [String: String]? = nil, body: String? = nil, completionHandler: ((data: NSData?, response: NSHTTPURLResponse?, error: NSError?) -> Void)? = nil) -> NSURLSessionDataTask {
		let request = NSMutableURLRequest(URL: url)
		request.HTTPMethod = requestMethod.rawValue
		if let headers = headers {
			for (field, value) in headers {
				request.addValue(value, forHTTPHeaderField: field)
			}
		}

		if let body = body {
			if let encodedBody = body.dataUsingEncoding(NSUTF8StringEncoding) {
				request.HTTPBody = encodedBody
			}
		}
		let session = NSURLSession.sharedSession()
		let task = session.dataTaskWithRequest(request) { data, response, error in
			if let handler = completionHandler {
				guard error == nil else {
					handler(data: data, response: response as? NSHTTPURLResponse ?? nil, error: error)
					return
				}
				guard let httpResponse = response as? NSHTTPURLResponse else {
					var detailError: NSError
					if response == nil {
						detailError = Error.UnexpectedNoResponse.asNSError()
					} else {
						detailError =  Error.UnexpectedResponseFormat.asNSError(detail: "Response was of type \(response.dynamicType)")
					}
					handler(data: data, response: nil, error: detailError)
					return
				}
				handler(data: data, response: httpResponse, error: error)
			}
		}
		task.resume()
		return task
	}

	/**
	Start a NSURLSession data task for a JSON request.
	
	This adds the ``Accept`` and, if a body is supplied, ``Content-Type`` headers with a value of ``application/json``.
	
	The JSON response is converted to native objects before calling the completion handler.
	*/
	func makeJSONDataRequest(url: NSURL, requestMethod: MethodType, var headers: [String: String]! = nil, body: String? = nil,
		dataPreprocessor: ((NSData) -> NSData)? = nil,
		completionHandler: ((jsonObject: AnyObject?, response: NSHTTPURLResponse?, error: NSError?) -> Void)? = nil) -> NSURLSessionDataTask {

			if headers == nil {
				headers = [String: String]()
			}
			headers["Accept"] = "application/json"
			if body != nil {
				headers["Content-Type"] = "application/json"
			}

			guard let handler = completionHandler else {
				// Caller provided no completion handler:
				return makeDataRequest(url, requestMethod: requestMethod, headers: headers, body: body)
			}
			return makeDataRequest(url, requestMethod: requestMethod, headers: headers, body: body) { data, response, error in
				guard error == nil else {
					handler(jsonObject: nil, response: response, error: error)
					return
				}
				guard let data = data else {
					handler(jsonObject: nil, response: response, error: Error.UnexpectedNoData.asNSError())
					return
				}

				var processedData: NSData
				if let preprocessor = dataPreprocessor {
					processedData = preprocessor(data)
				} else {
					processedData = data
				}

				let (jsonData, jsonError) = self.parseJSON(processedData)

				guard jsonError == nil else {
					handler(jsonObject:nil, response:response, error:jsonError)
					return
				}

				handler(jsonObject: jsonData, response: response, error: nil)
			}
	}


	/**
	Convert a native object (for example a Dictionary) to a String with a JSON representation of the native object.
	*/
	func objectToJsonString(obj: AnyObject) -> String? {
		//		if let data = try? NSJSONSerialization.dataWithJSONObject(obj, options: .PrettyPrinted) {
		if let data = try? NSJSONSerialization.dataWithJSONObject(obj, options: NSJSONWritingOptions(rawValue: 0)) {
			return String(data: data, encoding: NSUTF8StringEncoding)
		}
		return nil
	}

	/**
	Convert a JSON-containing NSData object to a Swift-native representation (e.g. Dictionary, Array, etc.)
	*/
	func parseJSON(data: NSData) -> (AnyObject?, NSError?) {
		if let parsedResult = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) {
			return (parsedResult, nil)
		} else {
			return (nil, Error.JSONDeserializationError.asNSError())
		}
	}
}

// MARK: Errors

extension WebClient {
	enum Error: Int {
		case NetworkRequestFailed = 1
		case UnparseableResponse = 2
		case InvalidLogin = 3
		case JSONSerializationError = 4
		case JSONDeserializationError = 5
		case UnexpectedResponseFormat = 6
		case UnexpectedNoData = 7
		case UnexpectedResponseCode = 8
		case UnexpectedJSONStructure = 9
		case UnexpectedNoResponse = 10
		case PreconditionNotMet = 11

		var description: String {
			switch self {
			case NetworkRequestFailed: return "Network request failed"
			case UnparseableResponse: return "Unable to parse response"
			case InvalidLogin: return "Authentication failed with the provided username and password"
			case JSONSerializationError: return "Unable to convert object to JSON"
			case JSONDeserializationError: return "Unable to convert JSON string to an object"
			case UnexpectedResponseFormat: return "Unexpected response format"
			case UnexpectedNoData: return "Response data was unexpectedly missing"
			case UnexpectedResponseCode: return "Unexpected response code"
			case UnexpectedJSONStructure: return "Error parsing JSON: unexpected JSON structure"
			case UnexpectedNoResponse: return "Error parsing JSON: unexpected JSON structure"
			case PreconditionNotMet: return "Precondition not met"
			}
		}

		func asNSError(domain: String = "WebClient", detail: String? = nil) -> NSError {
			var info = self.description
			if let detail = detail {
				info += ". \(detail)"
			}
			let userInfo = [
				NSLocalizedDescriptionKey: info
			]
			return NSError(domain: domain, code: self.rawValue, userInfo: userInfo)
		}
	}
}

/**
Example PathComponentProviding-implementing enum:

enum AutoHousePaths: String, PathComponentProviding {
	case Fridge = "refrigerator"
	case Fan = "fan/{room}"
	func pathComponent() -> String { return self.rawValue }
}
*/
protocol PathComponentProviding {
	func pathComponent() -> String
}

struct WebClientRouter {
	let encoder = URLEncoder.sharedInstance
	let baseURL: NSURL

	init?(baseURL: String) {
		if let url = NSURL(string: baseURL) {
			self.baseURL = url
		} else {
			return nil
		}
	}

	/**
	Provides a URL for the PathComponentProviding enum value, substituting the provided path and query parameters, if any.
	*/
	func url(enumObject: PathComponentProviding, pathParams: [String: String]? = nil, queryParams: [String: String]? = nil) -> NSURL? {
		var path = enumObject.pathComponent()
		if let params = pathParams {
			path = encoder.pathWithEncodedReplacements(path, params: params)
		}
		let url = baseURL.URLByAppendingPathComponent(path)
		if let params = queryParams where params.count > 0, let queryString = encoder.encodedQueryStringFromParams(params) {
			return NSURL(string: queryString, relativeToURL: url)
		} else {
			return url
		}
	}
}