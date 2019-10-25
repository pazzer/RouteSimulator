//
//  CGRect+.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 25/10/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}
