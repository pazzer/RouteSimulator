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
            operation = fetchOperationBlock(atIndex: operationIndex)
        }
    }
    
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
        guard let operation = self.operation else {
            fatalError("can't step - no pending operation")
        }
        // DELEGATE RE. NEXT OP????
//        self.blockData!.block()
//        if operationIndex == operations.count - 1 {
//            blockData = nil
//            delegate.routeBot(self, didCompleteSequence: sequenceIndex, named: currentSequenceName)
//        } else {
//            operationIndex += 1
//        }
    }
    
    @IBAction func jump(_ sender: Any) {
        if let _ = operation {
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
//        guard operationIndex == 0 && blockData != nil else {
//            return
//        }
//        delegate.routeBot(self, isSkippingSequence: sequenceIndex, named: currentSequenceName)
//        if sequenceIndex < sequences.count {
//            teeUpNextSequence()
//        } else {
//            delegate.routeBotCompletedAllSequences(self)
//        }
        
    }
    
    func execute(blocks: [() -> Void]) {
        var counter = 0
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { (observer, activity) in
            if activity.contains(.beforeWaiting) && counter < blocks.count {
                
                let block = blocks[counter]
                RunLoop.main.perform {
                    block()
                }
                counter += 1
            } else {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
            }
        }
        
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
    }
    
    var operation: (block: () -> Void, operation: Operation)?
    
    func completeSequence() {
        assert(operation != nil, "complete sequence invalid - no pending operations")
        
        var outstandingOps = [() -> Void]()
        
        while true {
            
            let operation = self.operation!
            
            let opName = operation.operation.rawValue
            let opIndex = self.operationIndex!
            let isTest = operation.operation.isTest
            
            outstandingOps.append {
                self.delegate.routeBot(self, loadedOperation: opIndex, named: opName, isTest: isTest)
            }
            outstandingOps.append(operation.block)
            let nextOperation = operationIndex + 1
            if nextOperation == operations.count {
                break
            } else {
                operationIndex = nextOperation
            }
        }
        
        self.operation = nil
        
        outstandingOps.append {
            self.delegate.routeBot(self, didCompleteSequence: self.sequenceIndex, named: self.currentSequenceName)
        }
        
        execute(blocks: outstandingOps)
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
            block = moveCrosshairsToZone(data as! Int)
        case .tapAdd:
            block = tapAdd()
        case .tapRemove:
            block = tapRemove()
        case .setCrosshairsOnWaypoint:
            block = setCrosshairsOnWaypoint(named: data as! String)
        case .tapWaypoint:
            block = tapWaypoint(named: data as! String)
        case .setCrosshairsOnArrow:
            block = setCrosshairsOnArrow(originatingAt: data as! String)
        case .moveWaypointToZone:
            block = moveWaypointToZone(rawData: data as! NSDictionary)
            
            
            // Tests
        case .countArrows:
            block = self.countArrows(expected: data as! Int)
        case .countWaypoints:
            block = self.countWaypoints(expectedWaypoints: data as! Int)
        case .validateRouteNext:
            block = self.validateRouteNext(diagram: data as! String)
        case .validateSelection:
            block = self.validateSelection(expectedSelectionName: data as! String)
        case .validateRoutePrevious:
            block = self.validateRoutePrevious(diagram: data as! String)
        case .validateNodeLocation:
            block = self.validateNodeLocation(data as! String)
        case .validateArrowAbsence:
            block = self.validateArrowAbsence(waypointName: data as! String)
        case .validateArrowPresence:
            block = self.validateArrowPresence(waypointName: data as! String)
        case .validateArrowPosition:
            block = self.validateArrowPosition(waypointName: data as! String)
        case .deletedWaypoints:
            block = self.deletedWaypoints(names: data as! String)

        }
        

        return (block, operation)
        
    }

    // MARK: Operations
    
    func setCrosshairsOnWaypoint(named name: String) -> () -> Void {
        return {
            let node = self.routeViewController.canvas.node(named: name)
            self.routeViewController.move(self.routeViewController.crosshairs, to: node.center)
        }
    }
    
    func tapAdd() -> () -> Void {
        return {
            self.routeViewController.userTappedAdd(self)
        }
    }
    
    func tapRemove() -> () -> Void {
        return {
            self.routeViewController.userTappedRemove(self)
        }
    }
    
    func moveCrosshairsToZone(_ zone: Int) -> () -> Void {
        return {
            let pt = self.center(of: zone)
            self.routeViewController.move(self.routeViewController.crosshairs, to: pt)
        }
    }
    
    func tapWaypoint(named name: String) -> () -> Void{
        return {
            let node = self.routeViewController.canvas.node(named: name)
            self.routeViewController.handleTap(at: node.center)
        }
    }
    
    func setCrosshairsOnArrow(originatingAt waypointName: String) -> () -> Void {
        return {
            let next = self.routeViewController.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
            let pt⁰ = self.routeViewController.route.location(ofWaypointNamed: waypointName)
            let pt¹ = self.routeViewController.route.location(ofWaypointNamed: next)
            let midPoint = pt⁰.midpoint(pt¹)
            self.routeViewController.move(self.crosshairs, to: midPoint)
        }
    }
    
    func moveWaypointToZone(rawData: NSDictionary) -> () -> Void {
        return {
            let waypointName = rawData["waypoint"] as! String
            let zone = rawData["zone"] as! Int
            self.routeViewController.move(waypointNamed: waypointName, to: self.center(of: zone))
        }
    }
    
    
    // MARK: Evaluation
    
    func countArrows(expected: Int) -> () -> Void {
        return {
            let graphicsCount = self.routeViewController.canvas.graphics.filter { $0 is Arrow}.count
            let mapCount = self.routeViewController.arrows.count
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
            self.delegate.routeBot(self, evaluated: Operation.countArrows.rawValue, didPass: pass, details: msg)
        }
    }
    
    func countWaypoints(expectedWaypoints: Int) -> () -> Void {
        return {
            let pass: Bool
            let msg: String
            let actualWaypoints = self.routeViewController.route.numbeOfWaypoints
            let actualCircles = self.routeViewController.canvas.graphics.filter { $0 is Node }.count
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
            self.delegate.routeBot(self, evaluated: Operation.countWaypoints.rawValue, didPass: pass
                , details: msg)
        }
    }

    func deletedWaypoints(names: String) -> () -> Void {
        return {
            let expected = ConvertSeparatedStringToArray(names).sorted()
            let actual = self.routeViewController.deletedWaypoints.map({$0.name}).sorted()
            let pass = expected == actual
            let msg = pass ? "deleted waypoints array does consist of \(expected)" : "deleted waypoints array consists of \(actual), not \(expected)"
            self.delegate.routeBot(self, evaluated: Operation.deletedWaypoints.rawValue, didPass: pass, details: msg)
        }
    }
    
    func validateRouteNext(diagram: String) -> () -> Void {
        return {
            let comps = diagram.components(separatedBy: "→")
            let name = comps.first!
            var expectedNext = comps.last!
            var pass: Bool
            var msg: String
            if let actualNext = self.routeViewController.route.nameOfWaypointFollowing(waypointNamed: name) {
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
            self.delegate.routeBot(self, evaluated: Operation.validateRouteNext.rawValue, didPass: pass, details: msg)
        }
        
    }
    
    func validateRoutePrevious(diagram: String) -> () -> Void {
        return {
            var pass: Bool
            var msg: String
            let comps = diagram.components(separatedBy: "→")
            let expectedPrevious = comps.first!
            let name = comps.last!
            if expectedPrevious == "*" {
                if let actualPrevious = self.routeViewController.route.nameOfWaypointPreceeding(waypointNamed: name) {
                    pass = false
                    msg = "previous of \(name) is \(actualPrevious), not nil"
                } else {
                    pass = true
                    msg = "previous of \(name) is nil"
                }
            } else if let actualPrevious = self.routeViewController.route.nameOfWaypointPreceeding(waypointNamed: name) {
                pass = actualPrevious == expectedPrevious
                msg = pass ? "previous of \(name) is \(expectedPrevious)" : "previous of \(name) is \(actualPrevious), not \(expectedPrevious)"
            } else {
                pass = false
                msg = "previous of \(name) is nil, not \(expectedPrevious)"
            }
            
            self.delegate.routeBot(self, evaluated: Operation.validateRoutePrevious.rawValue, didPass: pass, details: msg)
        }
    }
    
    func validateSelection(expectedSelectionName: String) -> () -> Void {
        
        return {
            let pass: Bool
            let msg: String
            
            if expectedSelectionName == "*" {
                if let actualSelectionName = self.routeViewController.selection?.name {
                    pass = false
                    msg = "selection is \(actualSelectionName), not nil"
                } else {
                    pass = true
                    msg = "selection is nil"
                }
            } else if let selectionName = self.routeViewController.selection?.name {
                pass = selectionName == expectedSelectionName
                msg = pass ? "selection is \(expectedSelectionName)" : "selection is \(selectionName) not \(expectedSelectionName)"
            } else {
                pass = false
                msg = "selection is nil, not \(expectedSelectionName)"
            }
            self.delegate.routeBot(self, evaluated: Operation.validateSelection.rawValue, didPass: pass, details: msg)
        }
    }
    
    
    func validateNodeLocation(_ waypointName: String) -> () -> Void {
        return {
            let routePoint = self.routeViewController.route.location(ofWaypointNamed: waypointName)
            let nodePoint = self.routeViewController.node(named: waypointName).center
            let pass: Bool
            let msg: String
            if nodePoint == routePoint {
                pass = true
                msg = "waypoint and corresponding node report same location (\(routePoint))"
            } else {
                pass = false
                msg = "waypoint location \(routePoint) (zone \(self.zone(containing: routePoint)) differs from node location \(nodePoint) (zone \(self.zone(containing: nodePoint))"
            }
            self.delegate.routeBot(self, evaluated: Operation.validateNodeLocation.rawValue, didPass: pass, details: msg)
        }
    }
    
    func validateArrowPresence(waypointName: String) -> () -> Void {
        return {
            var pass: Bool
            var msg: String
            if let arrow = self.routeViewController.arrows[waypointName] {
                if let _ = self.routeViewController.canvas.graphics.first(where: {$0 === arrow}) {
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
            
            self.delegate.routeBot(self, evaluated: Operation.validateArrowPresence.rawValue, didPass: pass, details: msg)
        }
        
    }
    
    func validateArrowAbsence(waypointName: String) -> () -> Void {
        return {
            let pass: Bool
            let msg: String
            if let arrow = self.routeViewController.arrows[waypointName] {
                pass = false
                if let _ = self.routeViewController.canvas.graphics.first(where: {$0 === arrow}) {
                    msg = "\(waypointName) does have arrow in arrow-map, and this arrow is on the canvas"
                } else {
                    msg = "\(waypointName) does have arrow in arrow-map, but this arrow is not present on the canvas"
                }
            } else {
                pass = true
                msg = "\(waypointName) does not appear as a key in arrow-map"
            }
            self.delegate.routeBot(self, evaluated: Operation.validateArrowAbsence.rawValue, didPass: pass, details: msg)
        }
    }
    
    func validateArrowPosition(waypointName: String) -> () -> Void {
        return {
            let pass: Bool
            let msg: String
            
            let arrow = self.routeViewController.arrows[waypointName]!
            
            let location⁰ = self.routeViewController.route.location(ofWaypointNamed: waypointName)
            let nextName = self.routeViewController.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
            let location¹ = self.routeViewController.route.location(ofWaypointNamed: nextName)
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
            
            assert(self.routeViewController.canvas.graphics.first(where: {$0 === arrow}) != nil)
            if arrow.contains(midpoint) && gradsOk {
                msg = "arrow emanating from \(waypointName) is correctly positioned"
                pass = true
            } else {
                msg = "arrow emanating from \(waypointName) is not correctly positioned"
                pass = false
            }
            self.delegate.routeBot(self, evaluated: Operation.validateArrowPosition.rawValue, didPass: pass, details: msg)
        }

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
    
    func zone(containing point: CGPoint) -> Int {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = routeViewController.canvas.bounds.width / nCols
        let zoneHeight = routeViewController.canvas.bounds.height / nRows
        
        let row = floor(point.y / zoneHeight)
        let col = floor(point.x / zoneWidth)
        
        return Int(row * nCols + col)
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
