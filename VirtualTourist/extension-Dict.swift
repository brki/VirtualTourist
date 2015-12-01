//
//  extension-Dict.swift
//  VirtualTourist
//
//  Created by Brian on 01/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

func +<K, V> (var left: [K : V], right: [K : V]) -> [K: V] {
	for (k, v) in right {
		left[k] = v
	}
	return left
}