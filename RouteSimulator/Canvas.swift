//
//  Canvas.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 10/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

class Canvas: UIView {
    
    private(set) var graphics = [Graphic]()
    
    func add(_ graphic: Graphic) {
        graphics.append(graphic)
        setNeedsDisplay(graphic.frame)
        
    }
    
    func remove(_ graphic: Graphic) {
        if let index = graphics.firstIndex(where: {$0 === graphic}) {
            graphics.remove(at: index)
            setNeedsDisplay(graphic.frame)
        } else {
            fatalError("Can't find \(String(describing: graphic))")
        }
    }
    
    func insert(_ newGraphic: Graphic, below graphic: Graphic) {
        guard let index = graphics.firstIndex(where: {$0 === graphic}) else {
            fatalError("failed to find \(String(describing: graphic))")
        }
        if index == 0 {
            remove(graphic)
            add(newGraphic)
            add(graphic)
        } else {
            insert(newGraphic, at: index)
        }
        
    }
    
    func insert(_ graphic: Graphic, at index: Int) {
        graphics.insert(graphic, at: index)
        setNeedsDisplay(graphic.frame)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        graphics.forEach { (graphic) in
            graphic.draw(in: context, rect: rect)
        }
    }
    

}
