//
//  Circle.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

public class Circle: Graphic, CustomStringConvertible {
    
    init(center: CGPoint, radius: CGFloat, fill: UIColor, stroke: UIColor, label: String) {
        self.frame = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        self.fill = fill
        self.stroke = stroke
        self.label = label
        updatePaths()
        updateLabelSize()
    }
    
    var radius: CGFloat {
        get {
            return frame.width / 2
        } set {
            let oldFrame = frame
            frame = CGRect(x: oldFrame.origin.x - newValue, y: oldFrame.origin.y - newValue, width: newValue * 2, height: newValue * 2)

        }
    }
    
    private var labelSize = CGSize.zero
    
    var label: String = "" {
        didSet {
            updateLabelSize()
        }
    }
    
    private func updateLabelSize() {
        let label = self.label.trimmingCharacters(in: .whitespaces)
        if label.count > 0 {
            labelSize = NSString(string: label).size(withAttributes: labelAttributes)
        } else {
            labelSize = .zero
        }
    }
    
    var selected = false
    var frame: CGRect = .zero {
        didSet {
            updatePaths()
        }
    }
    
    let font = UIFont.systemFont(ofSize: 15.0, weight: .bold)
    
    lazy var labelAttributes: [NSAttributedString.Key : Any] = {
        return [NSAttributedString.Key.font: self.font, NSAttributedString.Key.foregroundColor: UIColor.white]
    }()
    
    func updatePaths() {
        path = UIBezierPath(ovalIn: frame)
        let haloRect = frame.insetBy(dx: 8, dy: 8)
        halo = UIBezierPath(ovalIn: haloRect)
        halo.lineWidth = 3
    }
    var fill: UIColor!
    var stroke: UIColor!
    var halo: UIBezierPath!
    var path: UIBezierPath!
    
    func draw(in context: CGContext, rect: CGRect) {
        fill?.setFill()
        stroke?.setStroke()
        path.fill()
        path.stroke()
        
        if selected {
            UIColor.white.setStroke()
            halo.stroke()
        }
        
        // Draw the label
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)
        guard trimmedLabel.count > 0 && labelSize != .zero else {
            return
        }
        
        let labelRect = CGRect(x: center.x - labelSize.width / 2, y: center.y - labelSize.height / 2, width: labelSize.width, height: labelSize.height)
        NSString(string: label).draw(in: labelRect, withAttributes: labelAttributes)
    }
    
    public var description: String {
        return "\(Unmanaged.passUnretained(self).toOpaque()); center: \(center), radius: \(radius), name: \(label)"
    }
}
