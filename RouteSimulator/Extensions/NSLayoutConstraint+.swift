//
//  NSLayoutConstraint+.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 13/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

import Foundation
import UIKit

extension NSLayoutConstraint {
    
    class func fitSubviewIntoSuperview(subview: UIView) {
        let superview = subview.superview!
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: superview.topAnchor),
            subview.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            subview.leftAnchor.constraint(equalTo: superview.leftAnchor),
            subview.rightAnchor.constraint(equalTo: superview.rightAnchor)
            ])
    }
}
