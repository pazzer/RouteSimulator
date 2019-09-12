//
//  Arrow.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

struct ArrowMetrics {
    let tipHeight: CGFloat
    let tipWidth: CGFloat
    let shaftWidth: CGFloat
}


class Arrow: Graphic {
    
    static var defaultMetrics = ArrowMetrics(tipHeight: 20, tipWidth: 20, shaftWidth: 5)
    
    private(set) var path = UIBezierPath()
    
    var metrics: ArrowMetrics!
    
    private(set) var start: CGPoint = .zero {
        didSet {
            updateProperties()
        }
    }
    
    private(set) var end: CGPoint = .zero {
        didSet {
            updateProperties()
        }
    }
    
    private var skipUpdates = false
    
    func contains(_ point: CGPoint) -> Bool {
        return path.contains(point)
    }
    
    private func updateProperties() {
        guard !skipUpdates else {
            return
        }
        
        center = calculateCenter()
        rotation = start.bearing(to: end)
        transform = calculateTransform()
        path = end.equalTo(start) ? UIBezierPath() : calculatePath()
        frame = path.bounds
    }
    
    init(start: CGPoint, end: CGPoint, metrics: ArrowMetrics? = nil) {
        
        self.metrics = metrics ?? Arrow.defaultMetrics
        self.start = start
        self.end = end
        updateProperties()
    }
    
    func update(end: CGPoint) {
        self.end = end
    }
    
    func update(start: CGPoint) {
        self.start = start
    }
    
    private var transform = CGAffineTransform()
    
    private func calculatePath() -> UIBezierPath {
        let unrotatedFrame = CGRect(x: center.x - metrics.tipWidth / 2, y: center.y - height / 2, width: metrics.tipWidth, height: height)
        let tip = CGPoint(x: unrotatedFrame.midX, y: unrotatedFrame.minY)
        let unrotatedCoordinates: [CGPoint]
        if unrotatedFrame.height < metrics.tipHeight {
            let tipRads = atan(metrics.tipHeight / (metrics.tipWidth / 2))
            let opp = unrotatedFrame.height
            let adj = opp / tan(tipRads)
            
            let rightWing = CGPoint(x: tip.x + adj, y: tip.y + opp)
            let leftWing = CGPoint(x: tip.x - adj, y: tip.y + opp)
            unrotatedCoordinates = [tip, leftWing, rightWing]
            
        } else {
            let tipFlat = unrotatedFrame.minY + metrics.tipHeight
            let rightWingTip = CGPoint(x: unrotatedFrame.maxX, y: tipFlat)
            let rightWingOrigin = CGPoint(x: center.x + metrics.shaftWidth / 2, y: tipFlat)
            let rightShaftOrigin = CGPoint(x: center.x + metrics.shaftWidth / 2, y: unrotatedFrame.maxY)
            let leftShaftOrigin = CGPoint(x: center.x - metrics.shaftWidth / 2, y: unrotatedFrame.maxY)
            let leftWingOrigin = CGPoint(x: center.x - metrics.shaftWidth / 2, y: tipFlat)
            let leftWingTip = CGPoint(x: unrotatedFrame.minX, y: tipFlat)
            unrotatedCoordinates = [tip, rightWingTip, rightWingOrigin, rightShaftOrigin, leftShaftOrigin, leftWingOrigin, leftWingTip]
        }
        
        return makePathFrom(unrotatedCoordinates: unrotatedCoordinates)
    }
    
    private func makePathFrom(unrotatedCoordinates: [CGPoint]) -> UIBezierPath {
        let rotatedCoordinates = unrotatedCoordinates.map { $0.applying(transform) }
        
        let path = UIBezierPath()
        path.move(to: rotatedCoordinates[0])
        rotatedCoordinates.dropFirst().forEach { (coordinate) in
            path.addLine(to: coordinate)
        }
        path.close()
        return path
    }
    
    func calculateTransform() -> CGAffineTransform {
        let rotation = CGAffineTransform(rotationAngle: CGFloat(self.rotation.value))
        let rotatedCenter = center.applying(rotation)
        let translationPt = CGPoint(x: center.x - rotatedCenter.x, y: center.y - rotatedCenter.y)
        let translation = CGAffineTransform(translationX: translationPt.x, y: translationPt.y)
        return rotation.concatenating(translation)
    }
    
    private func calculateCenter() -> CGPoint {
        let midx = (start.x + end.x) / 2
        let midy = (start.y + end.y) / 2
        return CGPoint(x: midx, y: midy)
    }
    
    private var height: CGFloat {
        let xDelta = abs(end.x - start.x)
        let yDelta = abs(end.y - start.y)
        return hypot(xDelta, yDelta)
    }
    
    func update(start: CGPoint, end: CGPoint) {
        skipUpdates = true
        self.start = start
        skipUpdates = false
        self.end = end
    }
    
    private(set) var rotation = Measurement(value: 0, unit: UnitAngle.radians)
    
    var center = CGPoint.zero
    
    var frame = CGRect.zero
    
    var selected = false
    
    var isLocked = false
    
    func draw(in context: CGContext, rect: CGRect) {
        UIColor.gray.setFill()
        path.fill()
        
        
    }
    

}

