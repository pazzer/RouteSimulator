//
//  NamedCircle.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

//class NamedCircle: Circle, CustomStringConvertible {
//    
//    var description: String {
//        return name ?? "-"
//    }
//    
//    var name: String? {
//        didSet {
//            updateLabelSize()
//        }
//    }
//    
//    init(center: CGPoint, radius: CGFloat, fill: UIColor, stroke: UIColor, name: String? = nil) {
//        self.name = name
//        super.init(center: center, radius: radius, fill: fill, stroke: stroke)
//        updateLabelSize()
//    }
//    
//    private var labelSize = CGSize.zero
//    
//    private func updateLabelSize() {
//        guard let name = self.name else {
//            labelSize = .zero
//            return
//        }
//        let label = NSString(string: name)
//        labelSize = label.size(withAttributes: nameAttributes)
//    }
//    
//    let font = UIFont.systemFont(ofSize: 15.0, weight: .bold)
//    
//    lazy var nameAttributes: [NSAttributedString.Key : Any] = {
//        return [NSAttributedString.Key.font: self.font, NSAttributedString.Key.foregroundColor: UIColor.white]
//    }()
//    
//    override func draw(in context: CGContext, rect: CGRect) {
//        super.draw(in: context, rect: rect)
//        guard let name = self.name else {
//            return
//        }
//        let labelRect = CGRect(x: center.x - labelSize.width / 2, y: center.y - labelSize.height / 2, width: labelSize.width, height: labelSize.height)
//        NSString(string: name).draw(in: labelRect, withAttributes: nameAttributes)
//    }
//}
