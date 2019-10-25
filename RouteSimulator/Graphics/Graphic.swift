//
//  Graphic.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

protocol Graphic: class {
    var frame: CGRect { get set }
    var center: CGPoint { get set }
    var hidden: Bool { get set }
    var selected: Bool { get set }
    func draw(in context: CGContext, rect: CGRect)
    func contains(_ point: CGPoint) -> Bool
    
}

extension Graphic {
    
    func contains(_ point: CGPoint) -> Bool {
        return frame.contains(point)
    }
    
    var center: CGPoint {
        get {
            return CGPoint(x: frame.midX, y: frame.midY)
        } set {
            let oldFrame = self.frame
            self.frame = CGRect(x: newValue.x - oldFrame.width / 2, y: newValue.y - oldFrame.height / 2, width: oldFrame.width, height: oldFrame.height)
        }
    }
    
    func translate(translation: CGPoint) {
        let center = self.center
        self.center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
    }
}








