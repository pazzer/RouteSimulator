//
//  DashedLineView.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

class DashedLineView: UIView {

    let dashedLine = CAShapeLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    func commonInit() {
        guard dashedLine.superlayer == nil else {
            return
        }
        layer.addSublayer(dashedLine)
        buildDashedLineLayer()
        
    }
    
    func buildDashedLineLayer() {
        let path = UIBezierPath()
        dashedLine.frame = layer.bounds
        if frame.width > frame.height {
            // horizontal line
            path.move(to: CGPoint(x: dashedLine.bounds.minX, y: dashedLine.bounds.midY))
            path.addLine(to: CGPoint(x: dashedLine.bounds.maxX, y: dashedLine.bounds.midY))
        } else {
            path.move(to: CGPoint(x: dashedLine.bounds.midX, y: dashedLine.bounds.minY))
            path.addLine(to: CGPoint(x: dashedLine.bounds.midX, y: dashedLine.bounds.maxY))
        }
        
        dashedLine.lineWidth = 1
        dashedLine.lineDashPattern = [2,2]
        dashedLine.fillColor = UIColor.clear.cgColor
        dashedLine.strokeColor = UIColor.gray.cgColor
        dashedLine.path = path.cgPath
    }
}
