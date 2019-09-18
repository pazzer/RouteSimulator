//
//  File.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

fileprivate class Waypoint {
    var name: String
    var location: CGPoint
    var next: Waypoint?
    
    init(name: String, location: CGPoint) {
        self.name = name
        self.location = location
    }
}

class Route: CustomStringConvertible {
    
    private var waypoints = [Waypoint]()
    
    private func waypoint(named name: String) -> Waypoint {
        return waypoints.first(where: { $0.name == name })!
    }
    
    func remove(waypointNamed name: String) {
        if let previous = nameOfWaypointPreceeding(waypointNamed: name) {
            unsetNext(ofWaypointNamed: previous)
        }
        waypoints.removeAll(where: { $0.name == name })
    }
    
    func add(waypointNamed name: String, at location: CGPoint) {
        assert(!waypointNames.contains(name))
        let waypoint = Waypoint(name: name, location: location)
        waypoints.append(waypoint)
    }
    
    func unsetNext(ofWaypointNamed name: String) {
        let waypoint = self.waypoint(named: name)
        waypoint.next = nil
    }
    
    func setNext(ofWaypointNamed name: String, toWaypointNamed nextName: String) {
        if let previous = nameOfWaypointPreceeding(waypointNamed: nextName) {
            unsetNext(ofWaypointNamed: previous)
        }
        
        let waypoint = self.waypoint(named: name)
        let next = self.waypoint(named: nextName)
        waypoint.next = next
    }
    
    func updateLocation(ofWaypointNamed name: String, to location: CGPoint) {
        let waypoint = self.waypoint(named: name)
        waypoint.location = location
    }
    
    func location(ofWaypointNamed name: String) -> CGPoint {
        let waypoint = self.waypoint(named: name)
        return waypoint.location
    }
    
    func nameOfWaypointFollowing(waypointNamed name: String) -> String? {
        let waypoint = self.waypoint(named: name)
        return waypoint.next?.name
    }
    
    func nameOfWaypointPreceeding(waypointNamed name: String) -> String? {
        return waypoints.first(where: { $0.next?.name == name })?.name
    }
    
    var numbeOfWaypoints: Int {
        return waypoints.count
    }
    
    var waypointNames: [String] {
        return waypoints.map { $0.name }
    }

    var description: String {
        var string = ""
        
        for name in waypointNames.sorted() {
            let waypoint = self.waypoint(named: name)
            if let next = waypoint.next?.name {
                string.append("\(waypoint.name) → \(next)\n")
            } else {
                string.append("\(waypoint.name)\n")
            }
        }
        return string
        
        
        
    }
    
    func circularRelationshipExistsBetween(waypointNamed name⁰: String, and name¹: String) -> Bool {
        guard let next⁰ = nameOfWaypointFollowing(waypointNamed: name⁰) else {
            return false
        }
        
        guard let next¹ = nameOfWaypointFollowing(waypointNamed: name¹) else {
            return false
        }
        
        return next⁰ == name¹ && next¹ == name⁰
    }

    
    func clear() {
        waypoints.removeAll(keepingCapacity: true)
    }
}
