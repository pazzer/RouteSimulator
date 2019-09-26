//
//  PlistLoader.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 25/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation

func LoadPlist(at url: URL) -> Any {
    guard
        let data = try? Data(contentsOf: url)
        else {
            fatalError("failed to convert contents of \(url.lastPathComponent) to Data object")
    }
    
    var xmlFormat = PropertyListSerialization.PropertyListFormat.xml
    guard
        let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: &xmlFormat)
        else {
            fatalError("failed to deserialize data object")
    }
    return plist
}
