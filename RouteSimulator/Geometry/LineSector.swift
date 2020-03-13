//
//  LineSector.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

public struct LineSector: CustomStringConvertible {
    let gradient: CGFloat?
    let yIntercept: CGFloat?
    let xIntercept:CGFloat?
    let start: CGPoint
    let end: CGPoint
    
    init(start: CGPoint, end: CGPoint) {
        let Δx = end.x - start.x
        let Δy = end.y - start.y
        
        self.start = start
        self.end = end
        
        switch (Δx, Δy) {
            
        case (0, _):
            self.gradient = nil
            self.yIntercept = nil
            self.xIntercept = start.x
            
        case (_, 0):
            self.gradient = 0
            self.yIntercept = start.y
            self.xIntercept = nil
            
        default:
            self.gradient = Δy / Δx
            self.yIntercept = start.y - self.gradient! * start.x
            self.xIntercept = -1 * (self.yIntercept!) / self.gradient!
        }
    }
    
    var m: CGFloat? {
        return gradient
    }
    
    var c: CGFloat? {
        return yIntercept
    }
    
    var isVertical: Bool {
        return xIntercept != nil && gradient == nil
    }
    
    var isHorizontal: Bool {
        guard let gradient = self.gradient else { return false }
        return gradient == 0
    }
    
    func point(distanceFromOrigin distance: CGFloat) -> CGPoint {
        let length = hypot(end.x - start.x, end.y - start.y)
        let ratio = distance / length
        let x = ((1-ratio) * start.x) + (ratio * end.x)
        let y = ((1-ratio) * start.y) + (ratio * end.y)
        return CGPoint(x: x, y: y)
    }
    
    func parallelLineSectors(offset: CGFloat) -> (LineSector, LineSector) {
        let bearing = start.bearing(to: end)
        let direction = Direction(angle: bearing)
        
        var xDelta: CGFloat = 0
        var yDelta: CGFloat = 0
        
        if let gradient = self.gradient, gradient != 0 {
            let perpGradient = -1 / gradient
            let d = pow(1 + pow(perpGradient, 2), 0.5)
            xDelta = offset / d
            yDelta = abs(xDelta * perpGradient)
        }
        
        switch direction {
            
        case .north:
            xDelta = offset
        case .south:
            xDelta = -offset
        case .east:
            yDelta = offset
        case .west:
            yDelta = -offset
        case .northEast:
            break
        case .southEast:
            xDelta = -xDelta
        case .southWest:
            xDelta = -xDelta
            yDelta = -yDelta
        case .northWest:
            yDelta = -yDelta
        }
        
        // clockwise
        var a = CGPoint(x: start.x + xDelta, y: start.y + yDelta)
        var b = CGPoint(x: end.x + xDelta, y: end.y + yDelta)
        let clock = LineSector(start: a, end: b)
        
        // anticlockwise
        a = CGPoint(x: start.x - xDelta, y: start.y - yDelta)
        b = CGPoint(x: end.x - xDelta, y: end.y - yDelta)
        let antiClock = LineSector(start: a, end: b)
        
        return (clock, antiClock)
    }
    
    public var description: String {
        if let gradient = self.gradient, let yIntercept = self.yIntercept {
            if gradient == 0 {
                return "y = \(yIntercept)"
            } else {
                return "y = \(gradient) * x + \(yIntercept)"
            }
        } else {
            return "x = \(xIntercept!)"
        }
    }
}
