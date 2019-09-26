//
//  SquareCursor.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

public class Crosshairs: Graphic {
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
    
//    var center = CGPoint.zero {
//        didSet {
//            frame = CGRect(x: center.x - frame.size.width * 0.5, y: center.y - frame.size.height * 0.5, width: frame.size.width, height: frame.size.width)
//        }
//    }
    
    func updatePaths() {
        grayCircle = UIBezierPath(ovalIn: frame)
        let crosshairsRect = frame.insetBy(dx: 16, dy: 16)
        
        let verticalPath = UIBezierPath()
        verticalPath.move(to: CGPoint(x: crosshairsRect.midX, y: crosshairsRect.minY))
        verticalPath.addLine(to: CGPoint(x: crosshairsRect.midX, y: crosshairsRect.maxY))
        verticalPath.lineWidth = 2
        verticalCrosshair = verticalPath
        
        let horizontalPath = UIBezierPath()
        horizontalPath.move(to: CGPoint(x: crosshairsRect.minX, y: crosshairsRect.midY))
        horizontalPath.addLine(to: CGPoint(x: crosshairsRect.maxX, y: crosshairsRect.midY))
        horizontalPath.lineWidth = 2
        horizontalCrosshair = horizontalPath
    }

    
    let fill = #colorLiteral(red: 0.7952535152, green: 0.7952535152, blue: 0.7952535152, alpha: 0.3990426937)
    var grayCircle: UIBezierPath!
    var verticalCrosshair: UIBezierPath!
    var horizontalCrosshair: UIBezierPath!
    
    func draw(in context: CGContext, rect: CGRect) {
        fill.setFill()
        grayCircle.fill()
        #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1).setStroke()
        
        verticalCrosshair?.stroke()
        horizontalCrosshair?.stroke()
    }
}
