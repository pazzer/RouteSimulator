//
//  File.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 26/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

func ConvertSeparatedStringToArray(_ separatedString: String, separator: String = ",") -> [String] {
    var array: [String]
    if separatedString.contains(separator) {
        array = separatedString.components(separatedBy: separator)
        array = array.map({$0.trimmingCharacters(in: .whitespaces)})
    } else {
        array = [separatedString.trimmingCharacters(in: .whitespaces)]
    }
    return array
}

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
