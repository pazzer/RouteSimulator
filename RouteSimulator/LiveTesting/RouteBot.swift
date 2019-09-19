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
        case tapAdd = "TAP_ADD"
        case tapRemove = "TAP_REMOVE"
        case tapWaypoint = "TAP_WAYPOINT"
        
        case moveCrosshairsToZone = "MOVE_CROSSHAIRS_TO_ZONE"
        case moveWaypointToZone = "MOVE_WAYPOINT_TO_ZONE"
        
        case setCrosshairsOnWaypoint = "SET_CROSSHAIRS_ON_WAYPOINT"
        case setCrosshairsOnArrow = "SET_CROSSHAIRS_ON_ARROW"
        
        //Evaluation
        case countWaypoints = "COUNT_WAYPOINTS"
        case countArrows = "COUNT_ARROWS"
        
        case validateArrowPresence = "VALIDATE_ARROW_PRESENCE"
        case validateArrowAbsence = "VALIDATE_ARROW_ABSENCE"
        
        case validateRouteNext = "VALIDATE_ROUTE_NEXT"
        case validateRoutePrevious = "VALIDATE_ROUTE_PREVIOUS"
        
        case validateArrowPosition = "VALIDATE_ARROW_POSITION"
        
        case validateSelection = "VALIDATE_SELECTION"
        
        case validateNodeLocation = "VALIDATE_NODE_LOCATION"
        case deletedWaypoints = "DELETED_WAYPOINTS"
        
        var isTest: Bool {
            return [.countArrows, .countWaypoints, .validateRouteNext, .validateSelection, .validateRoutePrevious, .validateNodeLocation, .validateArrowAbsence, .validateArrowPresence, .validateArrowPosition, .deletedWaypoints].contains(self)
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
            blockData = fetchOperationBlock(atIndex: operationIndex)
        }
    }
    
    var blockData: (block: (() -> (Void)), operation: Operation)?
    
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
    
    var queue = [() -> Void]()
    
    @IBAction func step(_ sender: Any) {
        scheduleCounter = 0
        self.blockData!.block()
        if operationIndex == operations.count - 1 {
            blockData = nil
            delegate.routeBot(self, didCompleteSequence: sequenceIndex, named: currentSequenceName)
        } else {
            operationIndex += 1
        }
    }
    
    @IBAction func jump(_ sender: Any) {
        
        if let _ = blockData {
            
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
        guard operationIndex == 0 && blockData != nil else {
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
            let block = blockData!.block
            if blockData!.operation.isTest {
                schedule { block() }
            } else {
                block()
            }
            
            let nextOperation = operationIndex + 1
            if nextOperation == operations.count {
                break
            } else {
                operationIndex = nextOperation
            }
        }
        schedule {
            self.blockData = nil
            self.delegate.routeBot(self, didCompleteSequence: self.sequenceIndex, named: self.currentSequenceName)
        }
        
        
    }
    
    func teeUpNextSequence() {
        assert(sequenceIndex < sequences.count)
        let sequence = sequences[sequenceIndex]
        sequenceIndex += 1
        delegate.routeBot(self, loadedSequence: sequenceIndex - 1, named: currentSequenceName)
        operations = sequence["operations"] as? [NSDictionary]
        operationIndex = 0
    }
    
    func fetchOperationBlock(atIndex index: Int) -> ((() -> Void), Operation) {
        let rawOperation = operations[index]
        let data = rawOperation["data"] as Any?
        var block: (() -> Void)!
        let operationName = rawOperation["operation"] as! String
        let operation = Operation(rawValue: operationName)!
        
        switch operation {
            
            // Route Editing
            
        case .moveCrosshairsToZone:
            block = { self.moveCrosshairsToZone(data as! Int) }
        case .tapAdd:
            block = { self.tapAdd() }
        case .tapRemove:
            block = { self.tapRemove() }
        case .setCrosshairsOnWaypoint:
            block = { self.setCrosshairsOnWaypoint(named: data as! String) }
        case .tapWaypoint:
            block = { self.tapWaypoint(named: data as! String) }
        case .setCrosshairsOnArrow:
            block = { self.setCrosshairsOnArrow(originatingAt: data as! String) }
        case .moveWaypointToZone:
            block = { self.moveWaypointToZone(rawData: data as! NSDictionary) }
            
            
            // Tests
        case .countArrows:
            block = { self.countArrows(expected: data as! Int) }
        case .countWaypoints:
            block = { self.countWaypoints(expectedWaypoints: data as! Int) }
        case .validateRouteNext:
            block = { self.validateRouteNext(diagram: data as! String)}
        case .validateSelection:
            block = { self.validateSelection(expectedSelectionName: data as! String)}
        case .validateRoutePrevious:
            block = { self.validateRoutePrevious(diagram: data as! String) }
        case .validateNodeLocation:
            block = { self.validateNodeLocation(data as! String) }
        case .validateArrowAbsence:
            block = { self.validateArrowAbsence(waypointName: data as! String)}
        case .validateArrowPresence:
            block = { self.validateArrowPresence(waypointName: data as! String)}
        case .validateArrowPosition:
            block = { self.validateArrowPosition(waypointName: data as! String)}
        case .deletedWaypoints:
            block = { self.deletedWaypoints(names: data as! String) }

        default:
            break
        }
        
        schedule {
            self.delegate.routeBot(self, loadedOperation: self.operationIndex, named: operationName, isTest: operation.isTest)
        }
        
        
        return (block, operation)
        
    }
    
    var scheduleCounter = 0
    var scheduleInterval = 0.025
    
    // MARK: Operations
    
    func setCrosshairsOnWaypoint(named name: String){
        schedule {
            let node = self.routeViewController.canvas.node(named: name)
            self.routeViewController.move(self.routeViewController.crosshairs, to: node.center)
        }
    }
    
    func tapAdd() {
        schedule {
            self.routeViewController.userTappedAdd(self)
        }
    }
    
    func tapRemove() {
        schedule {
            self.routeViewController.userTappedRemove(self)
        }
    }
    
    func moveCrosshairsToZone(_ zone: Int) {
        schedule {
            let pt = self.center(of: zone)
            self.routeViewController.move(self.routeViewController.crosshairs, to: pt)
        }
    }
    
    func tapWaypoint(named name: String) {
        schedule {
            let node = self.routeViewController.canvas.node(named: name)
            self.routeViewController.handleTap(at: node.center)
        }
    }
    
    func setCrosshairsOnArrow(originatingAt waypointName: String) {
        schedule {
            let next = self.routeViewController.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
            let pt⁰ = self.routeViewController.route.location(ofWaypointNamed: waypointName)
            let pt¹ = self.routeViewController.route.location(ofWaypointNamed: next)
            let midPoint = pt⁰.midpoint(pt¹)
            self.routeViewController.move(self.crosshairs, to: midPoint)
        }
    }
    
    func moveWaypointToZone(rawData: NSDictionary) {
        schedule {
            let waypointName = rawData["waypoint"] as! String
            let zone = rawData["zone"] as! Int
            self.routeViewController.move(waypointNamed: waypointName, to: self.center(of: zone))
        }
    }
    
    // OLD -->

    
    
    
    func schedule(block: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: Double(scheduleCounter) * scheduleInterval, repeats: false) { (_) in
            block()
        }
        scheduleCounter += 1
    }
    
    
    
    

    
    // MARK: Evaluation
    
    func deletedWaypoints(names: String) {
        let expected = ConvertSeparatedStringToArray(names).sorted()
        let actual = routeViewController.deletedWaypoints.map({$0.name}).sorted()
        let pass = expected == actual
        let msg = pass ? "deleted waypoints array does consist of \(expected)" : "deleted waypoints array consists of \(actual), not \(expected)"
        delegate.routeBot(self, evaluated: Operation.deletedWaypoints.rawValue, didPass: pass, details: msg)
    }
    
    func countNodes(expected: Int) {
        let actual = routeViewController.canvas.graphics.filter { $0 is Node}.count
        let pass = actual == expected
        var msg: String
        if pass {
            msg = "Node count is \(actual)"
        } else {
            msg = "Node count is \(actual), not \(expected)"
        }
        
        delegate.routeBot(self, evaluated: Operation.countWaypoints.rawValue, didPass: pass, details: msg)
    }
    
    func countWaypoints(expectedWaypoints: Int) {
        let pass: Bool
        let msg: String
        let actualWaypoints = routeViewController.route.numbeOfWaypoints
        let actualCircles = routeViewController.canvas.graphics.filter { $0 is Node }.count
        if actualWaypoints == expectedWaypoints {
            if actualCircles == actualWaypoints {
                pass = true
                msg = "Number of waypoints is \(expectedWaypoints)"
            } else {
                pass = false
                msg = "Number of waypoints is as expected \(expectedWaypoints), but number of circles on the canvas is not \(actualCircles)"
            }
        } else {
            pass = false
            msg = "Number of waypoints is \(actualWaypoints), not \(expectedWaypoints)"
        }
        delegate.routeBot(self, evaluated: Operation.countWaypoints.rawValue, didPass: pass
            , details: msg)
        
    }

    func countArrows(expected: Int) {
        let graphicsCount = routeViewController.canvas.graphics.filter { $0 is Arrow}.count
        let mapCount = routeViewController.arrows.count
        let pass: Bool
        let msg: String
        if expected == mapCount {
            if expected == graphicsCount {
                pass = true
                msg = "number of arrows is \(expected)"
            } else {
                pass = false
                msg = "arrow-map contains expected number of arrows \(expected), but number graphics on canvas is reported as \(graphicsCount)"
            }
        } else {
            pass = false
            msg = "number of arrows in arrow map is \(mapCount), not \(expected)"
        }
        delegate.routeBot(self, evaluated: Operation.countArrows.rawValue, didPass: pass, details: msg)
    }
    
    func validateRouteNext(diagram: String) {
        let comps = diagram.components(separatedBy: "→")
        let name = comps.first!
        var expectedNext = comps.last!
        var pass: Bool
        var msg: String
        if let actualNext = routeViewController.route.nameOfWaypointFollowing(waypointNamed: name) {
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
    
    func validateRoutePrevious(diagram: String) {
        let comps = diagram.components(separatedBy: "→")
        let expectedPrevious = comps.first!
        let name = comps.last!
        guard expectedPrevious != "*" else {
            validatePreviousIsNil(waypointName: name)
            return
        }
        var pass: Bool
        var msg: String
        if let actualPrevious = routeViewController.route.nameOfWaypointPreceeding(waypointNamed: name) {
            pass = actualPrevious == expectedPrevious
            msg = pass ? "previous of \(name) is \(expectedPrevious)" : "previous of \(name) is \(actualPrevious), not \(expectedPrevious)"
        } else {
            pass = false
            msg = "previous of \(name) is nil, not \(expectedPrevious)"
        }
        delegate.routeBot(self, evaluated: Operation.validateRoutePrevious.rawValue, didPass: pass, details: msg)
    }
    
    func validatePreviousIsNil(waypointName: String) {
        let pass: Bool
        let msg: String
        if let previous = routeViewController.route.nameOfWaypointPreceeding(waypointNamed: waypointName) {
            pass = false
            msg = "previous of \(waypointName) is \(previous), not nil"
        } else {
            pass = true
            msg = "previous of \(waypointName) is nil"
        }
        delegate.routeBot(self, evaluated: Operation.validateRoutePrevious.rawValue, didPass: pass, details: msg)
    }
    
    func validateSelection(expectedSelectionName: String) {
        guard expectedSelectionName != "*" else {
            validateSelectionIsNil()
            return
        }
        
        let pass: Bool
        let msg: String
        if let selectionName = routeViewController.selection?.name {
            pass = selectionName == expectedSelectionName
            msg = pass ? "selection is \(expectedSelectionName)" : "selection is \(selectionName) not \(expectedSelectionName)"
        } else {
            pass = false
            msg = "selection is nil, not \(expectedSelectionName)"
        }
        delegate.routeBot(self, evaluated: Operation.validateSelection.rawValue, didPass: pass, details: msg)
    }
    
    func validateSelectionIsNil() {
        let pass: Bool
        let msg: String
        if let selectionName = routeViewController.selection?.name {
            pass = false
            msg = "selection is \(selectionName), not nil"
        } else {
            pass = true
            msg = "selection is nil"
        }
        delegate.routeBot(self, evaluated: Operation.validateSelection.rawValue, didPass: pass, details: msg)
    }
    
    func validateNodeLocation(_ waypointName: String) {
        let routePoint = routeViewController.route.location(ofWaypointNamed: waypointName)
        let nodePoint = routeViewController.node(named: waypointName).center
        let pass: Bool
        let msg: String
        if nodePoint == routePoint {
            pass = true
            msg = "waypoint and corresponding node report same location (\(routePoint))"
        } else {
            pass = false
            msg = "waypoint location \(routePoint) (zone \(zone(containing: routePoint)) differs from node location \(nodePoint) (zone \(zone(containing: nodePoint))"
        }
        delegate.routeBot(self, evaluated: Operation.validateNodeLocation.rawValue, didPass: pass, details: msg)
    }
    
    func validateArrowPresence(waypointName: String) {
        var pass: Bool
        var msg: String
        if let arrow = routeViewController.arrows[waypointName] {
            if let _ = routeViewController.canvas.graphics.first(where: {$0 === arrow}) {
                pass = true
                msg = "found valid arrow for \(waypointName)"
            } else {
                pass = false
                msg = "found arrow in arrow-map for \(waypointName), but arrow not present on canvas"
            }
        } else {
            pass = false
            msg = "no key '\(waypointName)' in arrow-map"
        }
        
        delegate.routeBot(self, evaluated: Operation.validateArrowPresence.rawValue, didPass: pass, details: msg)
    }
    
    func validateArrowAbsence(waypointName: String) {
        let pass: Bool
        let msg: String
        if let arrow = routeViewController.arrows[waypointName] {
            pass = false
            if let _ = routeViewController.canvas.graphics.first(where: {$0 === arrow}) {
                msg = "\(waypointName) does have arrow in arrow-map, and this arrow is on the canvas"
            } else {
                msg = "\(waypointName) does have arrow in arrow-map, but this arrow is not present on the canvas"
            }
        } else {
            pass = true
            msg = "\(waypointName) does not appear as a key in arrow-map"
        }
        delegate.routeBot(self, evaluated: Operation.validateArrowAbsence.rawValue, didPass: pass, details: msg)
    }
    
    func validateArrowPosition(waypointName: String) {
        let pass: Bool
        let msg: String
        
        let arrow = routeViewController.arrows[waypointName]!
        
        let location⁰ = routeViewController.route.location(ofWaypointNamed: waypointName)
        let nextName = routeViewController.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
        let location¹ = routeViewController.route.location(ofWaypointNamed: nextName)
        let midpoint = location⁰.midpoint(location¹)
        
        let arrowGradient = LineSector(start: arrow.start, end: arrow.end).gradient
        let pointsGradient = LineSector(start: location⁰, end: location¹).gradient
        
        let gradsOk: Bool
        switch (arrowGradient, pointsGradient) {
        case let (arrowGradient?, pointsGradient?):
            gradsOk = abs(arrowGradient - pointsGradient) < 0.0001
        case (_?, nil), (nil, _?):
            gradsOk = false
        case (nil, nil):
            gradsOk = true
        }
        
        assert(routeViewController.canvas.graphics.first(where: {$0 === arrow}) != nil)
        if arrow.contains(midpoint) && gradsOk {
            msg = "arrow emanating from \(waypointName) is correctly positioned"
            pass = true
        } else {
            msg = "arrow emanating from \(waypointName) is not correctly positioned"
            pass = false
        }
        delegate.routeBot(self, evaluated: Operation.validateArrowPosition.rawValue, didPass: pass, details: msg)
    }
    
    
    

    
    
    
    // Working with zones
    
    var zoneSize: CGSize {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = routeViewController.canvas.bounds.width / nCols
        let zoneHeight = routeViewController.canvas.bounds.height / nRows
        
        return CGSize(width: zoneWidth, height: zoneHeight)
    }
    
    func origin(of zone: Int) -> CGPoint {
        
        let nCols = CGFloat(grid.columns)
        
        let (row, _) = modf(CGFloat(zone) / nCols)
        let col = CGFloat(zone) - (row * nCols)
        
        let minX = col * zoneSize.width
        let minY = row * zoneSize.height
        
        return CGPoint(x: minX, y: minY)
    }
    
    func center(of zone: Int) -> CGPoint {
        let origin = self.origin(of: zone)
        return CGPoint(x: origin.x + zoneSize.width * 0.5, y: origin.y + zoneSize.height * 0.5)
    }
    
    func randomPoint(in zone: Int) -> CGPoint {
        let origin = self.origin(of: zone)
        
        let x = CGFloat(arc4random_uniform(UInt32(zoneSize.width)) + UInt32(origin.x))
        let y = CGFloat(arc4random_uniform(UInt32(zoneSize.height)) + UInt32(origin.y))
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


func ConvertSeparatedStringToArray(_ separatedString: String, separator: String = ",") -> [String] {
    var array: [String]
    if separatedString.contains(separator) {
        array = separatedString.components(separatedBy: separator)
        array = array.map({$0.trimmingCharacters(in: .whitespaces)})
    } else {
        array = [separatedString.trimmingCharacters(in: .whitespaces)]
    }
    return array
}
