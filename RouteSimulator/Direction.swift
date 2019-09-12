//
//  Direction.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation

enum Direction {
    case north
    case south
    case east
    case west
    case northEast
    case southEast
    case southWest
    case northWest
    
    init(angle: Measurement<UnitAngle>) {
        let π = Double.pi
        switch true {
        case angle.value == 0:
            self = .north
        case angle.value == π:
            self = .south
        case angle.value == π / 2:
            self = .east
        case angle.value == π * 3 / 2:
            self = .west
        case angle.value < π / 2:
            self = .northEast
        case angle.value < π:
            self = .southEast
        case angle.value < π * 3 / 2:
            self = .southWest
        case angle.value < π * 2:
            self = .northWest
        default:
            fatalError()
        }
    }
}
