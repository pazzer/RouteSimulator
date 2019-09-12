//
//  File.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation

class Route: CustomStringConvertible {
    
    private var map = [String:String?]()
    
    var start: String?
    
    func remove(_ name: String) {
        assert(map.keys.contains(name))
        if let previous = self.previous(of: name) {
            map.updateValue(nil, forKey: previous)
        }
        map.removeValue(forKey: name)
        
    }
    
    func add(_ name: String) {
        assert(!map.keys.contains(name))
        map.updateValue(nil, forKey: name)
    }
    
    func setNext(of location: String, to otherLocation: String?) {
        assert(map.keys.contains(location))
        if let otherLocation = otherLocation {
            assert(map.keys.contains(otherLocation))
        }
        
        if let otherLocation = otherLocation, let previous = self.previous(of: otherLocation) {
            map.updateValue(nil, forKey: previous)
        }
        map.updateValue(otherLocation, forKey: location)
    }
    
    func next(of location: String) -> String? {
        assert(map.keys.contains(location))
        return map[location]!
    }
    
    func previous(of name: String) -> String? {
        return map.first(where: { (key, value) -> Bool in
            return value == name
        })?.key
    }
    
    var description: String {
        var string = ""
        for (k, v) in map {
            if let v = v {
                string.append("\(k) → \(v)\n")
            } else {
                string.append("\(k)\n")
            }
        }
        return string
    }
    
    func circularRelationshipExistsBetween(_ location: String, and otherLocation: String) -> Bool {
        guard let value⁰ = map[location], let next⁰ = value⁰ else {
            return false
        }
        guard let value¹ = map[otherLocation], let next¹ = value¹ else {
            return false
        }
        
        return next⁰ == otherLocation && next¹ == location
    }
    
    var locations: [String] {
        return Array(map.keys)
    }
}
