//
//  Rectangle.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

class Rectangle: Graphic {
    
    init(center: CGPoint, size: CGSize, fill: UIColor) {
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        self.fill = fill
        self.frame = CGRect(origin: origin, size: size)
    }
    
    var isLocked = false
    var selected = false
    var frame: CGRect = .zero
    var fill: UIColor!
    var stroke: UIColor!
    
    var path: UIBezierPath {
        return UIBezierPath(rect: frame)
    }
    
    func draw(in context: CGContext, rect: CGRect) {
        fill?.setFill()
        stroke?.setStroke()
        path.fill()
        path.stroke()
    }
}

