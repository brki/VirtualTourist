//
//  extension-Dict.swift
//  VirtualTourist
//
//  Created by Brian on 01/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import Foundation

/**
Redefine dictionary addition to mean add all items from right-hand side dict
to the left-hand side dict, overwriting any key/value pairs for which the
key already exists in the left-hand side dict.
*/
func +<K, V> (var left: [K : V], right: [K : V]) -> [K: V] {
	for (k, v) in right {
		left[k] = v
	}
	return left
}