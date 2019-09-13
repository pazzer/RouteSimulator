//
//  RouteBot.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

let NODE_FREE_ZONE = 0

protocol RouteBotDelegate {

    func routeBot(_ routeBot: RouteBot, loadedSequence index: Int, named name: String?)
    
    func routeBot(_ routeBot: RouteBot, loadedOperation index: Int, named name: String, isTest: Bool)
    
    func routeBot(_ routeBot: RouteBot, didCompleteSequence index: Int, named name: String?)
    
    func routeBotCompletedAllSequences(_ routeBot: RouteBot)
    
    func routeBot(_ routeBot: RouteBot, isSkippingSequence index: Int, named name: String?)
    
    func routeBot(_ routeBot: RouteBot, evaluated operation: String, didPass: Bool, details: String?)
}

extension RouteBotDelegate {

    func routeBot(_ routeBot: RouteBot, loadedSequence index: Int, named name: String?) { }
    func routeBot(_ routeBot: RouteBot, loadedOperation index: Int, named name: String, isTest: Bool) { }
    func routeBot(_ routeBot: RouteBot, didCompleteSequence index: Int, named name: String?) { }
    func routeBotCompletedAllSequences(_ routeBot: RouteBot) { }
    func routeBot(_ routeBot: RouteBot, isSkippingSequence index: Int, named name: String?) { }
}

class RouteBot {
    
    var routeViewController: RouteViewController!
    
    var crosshairs: Crosshairs {
        return routeViewController.crosshairs
    }
    
    enum Operation: String {
        
        // Construction
        case setCrosshairsOnNode = "SET_CROSSHAIRS_ON_NODE"
        case setCrosshairsOnArrow = "SET_CROSSHAIRS_ON_POLYLINE"
        case setCrosshairsInZone = "SET_CROSSHAIRS_IN_ZONE"
        
        case addNodesToZones = "ADD_NODES_TO_ZONES"
        
        case deleteNode = "DELETE_NODE"
        case deleteArrow = "DELETE_ARROW"
        case insertNode = "INSERT_NODE"
        
        case selectNode = "SELECT_NODE"
        case setNext = "SET_NEXT"
        
        //Evaluation
        case countNodes = "COUNT_NODES"
        case countArrows = "COUNT_ARROWS"
        case countArrowMap = "COUNT_ARROW_MAP"
        case validateRouteNext = "VALIDATE_ROUTE_NEXT"
        
        var isTest: Bool {
            return [.countArrows, .countNodes, .countArrowMap, .validateRouteNext].contains(self)
        }
    }
    
    private(set) var operations: [NSDictionary]!
    
    private(set) var sequences: [NSDictionary]! {
        didSet {
            teeUpNextSequence()
        }
    }
    
    var operationIndex: Int! {
        didSet {
            block = fetchOperationBlock(atIndex: operationIndex)
        }
    }
    
    var block: (() -> (Void))?
    
    var sequenceIndex = 0
    
    var delegate: RouteBotDelegate!
    
    func loadData(from plist: URL) {
        guard
            let data = try? Data(contentsOf: plist)
            else {
                fatalError("failed to convert contents of \(plist.lastPathComponent) to Data object")
        }
        
        var xmlFormat = PropertyListSerialization.PropertyListFormat.xml
        guard
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: &xmlFormat)
            else {
                fatalError("failed to deserialize data object")
        }
        sequences = plist as? [NSDictionary]
    }
    
    var currentSequenceName: String? {
        return sequences[sequenceIndex - 1].value(forKey: "name") as? String
    }
    
    @IBAction func step(_ sender: Any) {
        self.block!()
        if operationIndex == operations.count - 1 {
            block = nil
            delegate.routeBot(self, didCompleteSequence: sequenceIndex, named: currentSequenceName)
        } else {
            operationIndex += 1
        }
    }
    
    @IBAction func jump(_ sender: Any) {
        
        if let _ = block {
            completeSequence()
        } else {
            if sequenceIndex > sequences.count - 1 {
                delegate.routeBotCompletedAllSequences(self)
            } else {
                teeUpNextSequence()
            }
        }
    }
    
    @IBAction func skip(_ sender: Any) {
        guard operationIndex == 0 && block != nil else {
            return
        }
        delegate.routeBot(self, isSkippingSequence: sequenceIndex, named: currentSequenceName)
        if sequenceIndex < sequences.count {
            teeUpNextSequence()
        } else {
            delegate.routeBotCompletedAllSequences(self)
        }
        
    }
    
    func completeSequence() {
        while true {
            let start = DispatchTime.now()
            block!()
            let finish = DispatchTime.now()
            let duration = Double(finish.rawValue - start.rawValue)
            let remaining = Double(NSEC_PER_SEC / 4) - duration
            let nextOperation = operationIndex + 1
            if nextOperation == operations.count {
                break
            } else {
                operationIndex = nextOperation
            }
        }
        block = nil
        delegate.routeBot(self, didCompleteSequence: sequenceIndex, named: currentSequenceName)
    }
    
    func teeUpNextSequence() {
        assert(sequenceIndex < sequences.count)
        
        let sequence = sequences[sequenceIndex]
        sequenceIndex += 1
        let skip = sequence["skip"] as! Bool
        if skip == false {
            delegate.routeBot(self, loadedSequence: sequenceIndex - 1, named: currentSequenceName)
            operations = sequence["operations"] as? [NSDictionary]
            operationIndex = 0
        }
    }
    
    func fetchOperationBlock(atIndex index: Int) -> (() -> Void) {
        let rawOperation = operations[index]
        let data = rawOperation["data"] as Any
        var block: (() -> Void)!
        let operationName = rawOperation["operation"] as! String
        let operation = Operation(rawValue: operationName)!
        
        switch operation {
            // Route Editing
        case .addNodesToZones:
            block = { self.addNodesToZones(rawData: data as! NSDictionary) }
        case .setNext:
            block = { self.setNext(rawData: data as! NSDictionary) }
        case .selectNode:
            block = { self.selectNode(named: data as! String)}
        case .deleteArrow:
            block = { self.deleteArrow(startingAt: data as! String) }
        case .deleteNode:
            block = { self.deleteNode(named: data as! String)}
        case .insertNode:
            block = { self.insertNode(onArrowStartingAtNodeNamed: data as! String)}
            
            // Tests
        case .countArrows:
            block = { self.countArrows(expected: data as! Int) }
        case .countNodes:
            block = { self.countNodes(expected: data as! Int) }
        case .countArrowMap:
            block = { self.countArrowMap(expected: data as! Int) }
        case .validateRouteNext:
            block = { self.validateRouteNext(diagram: data as! String)}
            
        default:
            break
        }
        
        delegate.routeBot(self, loadedOperation: operationIndex, named: operationName, isTest: operation.isTest)
        
        return block
        
    }
    
    // MARK: Operations
    
    func setCrosshairsOnPoint(rawData: NSDictionary) {
        let point = CGPoint(from: rawData)
        routeViewController.move(crosshairs, to: point)
    }
    
    func setCrosshairsOnNode(named name: String) {
        let node = self.node(named: name)
        routeViewController.move(crosshairs, to: node.center)
    }
    
    func setCrosshairsOnArrowBetween(nodeNamed start: String, and end: String) {
        let node⁰ = node(named: start)
        let node¹ = node(named: end)
        
        let midpoint = node⁰.center.midpoint(node¹.center)
        routeViewController.move(crosshairs, to: midpoint)
    }
    
    func addNodesToZones(rawData: NSDictionary) {
        let zonesString = rawData["zones"] as! String
        let connected = rawData["connected"] as! Bool
        for string in zonesString.components(separatedBy: ",") {
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            let zone = Int(trimmed)!
            assert(zone != NODE_FREE_ZONE)
            let point = randomPoint(in: zone)
            routeViewController.move(crosshairs, to: point)
            routeViewController.userTappedAdd(self)
            if !connected {
                routeViewController.handleTap(at: crosshairs.center)
            }
        }
    }
    
    
    func selectNode(named name: String) {
        
        if name == "*" {
            if routeViewController.selection != nil {
                clearSelection()
            }
            return
        }
        
        if let selected = routeViewController.selection?.name, selected == name {
            return
        }
        
        routeViewController.move(crosshairs, to: CGPoint(x: -100, y: -100))
        let node = self.node(named: name)
        routeViewController.handleTap(at: node.center)
        routeViewController.move(crosshairs, to: CGPoint(x: 10, y: 10))
    }
    
    func insertNode(onArrowStartingAtNodeNamed nodeName: String) {
        clearSelection()
        let nextName = routeViewController.route.next(of: nodeName)!
        setCrosshairsOnArrowBetween(nodeNamed: nodeName, and: nextName)
        routeViewController.userTappedAdd(self)
    }
    
    func setNext(rawData: NSDictionary) {
        let diagram = rawData["diagram"] as! String
        let comps = diagram.components(separatedBy: "→")
        assert(comps.count == 2)
        let origin = comps.first!
        let source = comps.last!
        
        selectNode(named: origin)
        setCrosshairsOnNode(named: source)
        routeViewController.userTappedAdd(self)
    }
    
    func deleteArrow(startingAt nodeName: String) {
        clearSelection()
        let nextName = routeViewController.route.next(of: nodeName)!
        setCrosshairsOnArrowBetween(nodeNamed: nodeName, and: nextName)
        routeViewController.userTappedRemove(self)
    }
    
    func deleteNode(named nodeName: String) {
        setCrosshairsOnNode(named: nodeName)
        routeViewController.userTappedRemove(self)
    }
    
    func clearSelection() {
        let pt = randomPoint(in: NODE_FREE_ZONE)
        routeViewController.handleTap(at: pt)
    }
    
    // MARK: Evaluation
    
    func countNodes(expected: Int) {
        let actual = routeViewController.canvas.graphics.filter { $0 is Node}.count
        let pass = actual == expected
        var msg: String
        if pass {
            msg = "Node count is \(actual)"
        } else {
            msg = "Node count is \(actual), not \(expected)"
        }
        
        delegate.routeBot(self, evaluated: Operation.countNodes.rawValue, didPass: pass, details: msg)
    }
    
    func countArrows(expected: Int) {
        let actual = routeViewController.canvas.graphics.filter { $0 is Arrow}.count
        let pass = actual == expected
        var msg: String
        if pass {
            msg = "Arrow count is \(actual)"
        } else {
            msg = "Arrow count is \(actual), not \(expected)"
        }
        
        delegate.routeBot(self, evaluated: Operation.countArrows.rawValue, didPass: pass, details: msg)
    }
    
    func countArrowMap(expected: Int) {
        let actual = routeViewController.arrows.count
        let pass = actual == expected
        var msg: String
        if pass {
            msg = "Arrow map contains \(actual) entries."
        } else {
            msg = "Arrow map contains is \(actual), not \(expected)."
        }
        
        delegate.routeBot(self, evaluated: Operation.countArrowMap.rawValue, didPass: pass, details: msg)
    }
    
    func validateRouteNext(diagram: String) {
        let comps = diagram.components(separatedBy: "→")
        let name = comps.first!
        var expectedNext = comps.last!
        var pass: Bool
        var msg: String
        if let actualNext = routeViewController.route.next(of: name) {
            pass = actualNext == expectedNext
            if pass {
                msg = "next of '\(name)' is \(actualNext)."
            } else {
                expectedNext = expectedNext == "*" ? "nil" : expectedNext
                msg = "next of '\(name) is \(actualNext), not \(expectedNext)"
            }
        } else {
            pass = expectedNext == "*"
            if pass {
                msg = "next of \(name) is nil"
            } else {
                msg = "next of \(name) is nil, not \(expectedNext)"
            }
        }
        delegate.routeBot(self, evaluated: Operation.validateRouteNext.rawValue, didPass: pass, details: msg)
    }
    
    
    
    
    // Working with zones
    
    func randomPoint(in zone: Int) -> CGPoint {
        
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = routeViewController.canvas.bounds.width / nCols
        let zoneHeight = routeViewController.canvas.bounds.height / nRows
        
        let (row, _) = modf(CGFloat(zone) / nCols)
        let col = CGFloat(zone) - (row * nCols)
        
        let minX = col * zoneWidth
        let minY = row * zoneHeight
        let x = CGFloat(arc4random_uniform(UInt32(zoneWidth)) + UInt32(minX))
        let y = CGFloat(arc4random_uniform(UInt32(zoneHeight)) + UInt32(minY))
        return CGPoint(x: x, y: y)
    }
    
    func zone(containing point: CGPoint) -> Int {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = routeViewController.canvas.bounds.width / nCols
        let zoneHeight = routeViewController.canvas.bounds.height / nRows
        
        let row = floor(point.y / zoneHeight)
        let col = floor(point.x / zoneWidth)
        
        return Int(row * nCols + col)
    }
    
    func node(named name: String) -> Node {
        return routeViewController.canvas.graphics.first(where: { (graphic) -> Bool in
            if let node = graphic as? Node, node.name == name {
                return true
            } else {
                return false
            }
        }) as! Node
    }
    
}
