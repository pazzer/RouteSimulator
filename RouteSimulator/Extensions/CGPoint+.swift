//
//  CGPoint+.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

extension CGPoint {
    
    func midpoint(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (other.x + x) / 2, y: (other.y + y) / 2)
    }
    
    func distance(to other: CGPoint) -> CGFloat {
        return hypot(x - other.x, y - other.y)
    }
    
    func bearing(to other: CGPoint) -> Measurement<UnitAngle> {
        let Δx = other.x - x
        let Δy = other.y - y
        let radians: CGFloat
        let π = CGFloat.pi
        
        switch true {
            
        case Δx == 0:
            radians = Δy > 0 ? π : 0
            
        case Δy == 0:
            radians = Δx > 0 ? π / 2 :  (π * 3) / 2
            
        case Δx > 0 && Δy < 0:
            radians = atan(Δx / -Δy)
            
        case Δx > 0 && Δy > 0:
            radians = atan(Δy / Δx) + π / 2
            
        case Δx < 0 && Δy > 0:
            radians = atan(Δx / -Δy) + π
            
        case Δx < 0 && Δy < 0:
            radians = atan(Δy / Δx) + (π * 3) / 2
            
        default:
            fatalError()
        }
        
        return Measurement(value: Double(radians), unit: UnitAngle.radians)
    }
    
    init(from dict: NSDictionary) {
        let x = dict.value(forKey: "x") as! CGFloat
        let y = dict.value(forKey: "y") as! CGFloat
        self.init(x: x, y: y)
    }
}

