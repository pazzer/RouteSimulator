//
//  SquareCursor.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

class SquareCursor: Graphic {
    var frame: CGRect = .zero {
        didSet {
            updatePaths()
        }
    }
    
    var isLocked = false
    var selected: Bool = false
    init(center: CGPoint, size: CGSize) {
        frame = CGRect(x: center.x - size.width * 0.5, y: center.y - size.height * 0.5, width: size.width, height: size.height)
        updatePaths()
        
    }
    
    func updatePaths() {
        graySquare = UIBezierPath(rect: frame)
        let crosshairsSize = CGSize(width: 10, height: 10)
        crosshairs = UIBezierPath(rect: CGRect(x: center.x - crosshairsSize.width * 0.5, y: center.y - crosshairsSize.height * 0.5, width: crosshairsSize.width, height: crosshairsSize.height))
    }
    
    let fill = #colorLiteral(red: 0.7952535152, green: 0.7952535152, blue: 0.7952535152, alpha: 0.3990426937)
    var graySquare: UIBezierPath!
    var crosshairs: UIBezierPath!
    
    func draw(in context: CGContext, rect: CGRect) {
        fill.setFill()
        UIColor.black.setStroke()
        crosshairs.lineWidth = 2.0
        graySquare.fill()
        crosshairs.stroke()
    }
}
