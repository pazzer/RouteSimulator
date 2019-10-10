//
//  ViewController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 06/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

let NODE_FREE_ZONE = 0
let UNICODE_CAP_A = 65

let grid: (rows: Int, columns: Int) = (15, 8)


enum RouteUpdate {
    case create(name: String, location: CGPoint)
    case remove(name: String, location: CGPoint)
    case select(name: String)
    case deselect(name: String)
    case move(name: String, from: CGPoint, to: CGPoint, byPan: Bool)
    case setNext(name: String, new: String?)
    
    func undone() -> RouteUpdate {
        switch self {
        case .create(let name, let location):
            return .remove(name: name, location: location)
        case .remove(let name, let location):
            return .create(name: name, location: location)
        case .select(let name):
            return .deselect(name: name)
        case .deselect(let name):
            return .select(name: name)
        case .move(let name, let from, let to, _):
            return .move(name: name, from: to, to: from, byPan: false)
        default:
            fatalError()
        }
    }
}

class RouteViewController: UIViewController {


    
    // MARK:- ViewController Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _undoManager = UndoManager()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        crosshairs = Crosshairs(center: CGPoint(x: graphicsView.bounds.midX, y: graphicsView.bounds.maxX), size: CGSize(width: 120, height: 120))
        graphicsView.add(crosshairs)
        prepareForTesting()
        updateButtons()
    }
    
    // MARK:- Variables (stored and computed)
    
    var route = Route()
    
    var crosshairs: Crosshairs!
    
    weak var selection: Node? {
        didSet {
            if let old = oldValue {
                graphicsView.setNeedsDisplay(old.frame)
            }
            if let new = selection {
                graphicsView.setNeedsDisplay(new.frame)
            }
        }
    }
    
    var graphicsView: GraphicsView {
        return view as! GraphicsView
    }
    
    let nodeRadius = CGFloat(22.0)
    
    let arrowInset: CGFloat = 5
    
    private var _undoManager: UndoManager!
    
    override var undoManager: UndoManager? {
        return _undoManager
    }
    

    // MARK:- Outlets
    @IBOutlet weak var undoButton: UIBarButtonItem!
    
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    // MARK:- Actions/Handling Actions
    
    @IBAction func userPannedOnGraphicsView(_ pan: UIPanGestureRecognizer) {
        
        switch pan.state {
            
        case .began:
            let pt = pan.location(in: graphicsView)
            if crosshairs.contains(pt) {
                panningGraphic = crosshairs
            } else if let node = graphicsView.graphics.first(where: { (graphic) -> Bool in
                graphic is Node && graphic.contains(pt)
            }) as? Node {
                panningGraphic = node
                nodeLocationBeforePan = node.center
            }
            
        case .changed:
            
            if let node = panningGraphic as? Node {
                relocateNode(node, translation: pan.translation(in: graphicsView))
            } else if let crosshairs = panningGraphic as? Crosshairs {
                relocateGraphic(crosshairs, translation: pan.translation(in: graphicsView))
            }
            
            pan.setTranslation(CGPoint.zero, in: graphicsView)
            
        case .ended:
            if let node = panningGraphic as? Node, let initialLocation = nodeLocationBeforePan {
                runUpdates([.move(name: node.name, from: initialLocation, to: node.center, byPan: true)])
            }
            nodeLocationBeforePan = nil
            panningGraphic = nil

        default:
            break
        }
    }
    
    @IBAction func userTapped(_ tap: UITapGestureRecognizer) {
        handleTap(at: tap.location(in: graphicsView))
    }
    
    func handleTap(at point: CGPoint) {
        let graphicsUnderPoint = graphicsView.graphics.filter({ $0.frame.contains(point) })
        
        guard graphicsUnderPoint.count > 0 else {
            /* Tapping empty space clears any existing selection */
            if let _ = selection {
                instigateSelectionUpdate(newSelection: nil)
            }
            return
        }
        
        guard !graphicsUnderPoint.contains(where: {$0 is Crosshairs}) else {
            /* Tap on crosshairs always sets selection to nil */
            instigateSelectionUpdate(newSelection: nil)
            return
        }
        
        guard let node = graphicsUnderPoint.first(where: { $0 is Node }) as? Node, !node.selected else {
            /* Tap on selected node deselects it */
            instigateSelectionUpdate(newSelection: nil)
            return
        }
        
        instigateSelectionUpdate(newSelection: node.name)
    }
    
    @IBAction func undo(_ sender: Any) {
        undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        undoManager?.redo()
    }
    
    @IBAction func userTappedAdd(_ sender: Any) {
        switch (nodeUnderCursor, selection) {
        case (nil, nil):
            if let arrow = arrowUnderCursor {
                instigateInsertion(on: arrow)
            } else {
                instigateCreationOfNewWaypoint()
            }
        case let (nil, selection?):
            instigateExtension(from: selection.name)
        case let (nodeUnderCursor?, selection?):
            instigateRerouting(set: nodeUnderCursor.name, toFollow: selection.name)
        default:
            break
        }
    }
    
    @IBAction func userTappedRemove(_ sender: Any) {
        if let waypoint = nodeUnderCursor?.name {
            instigateRemoval(of: waypoint)
        } else if let arrow = arrowUnderCursor {
            guard let (waypoint, _) = arrows.first(where: {$1 === arrow}) else {
                fatalError("can't find arrow in <arrows>")
            }
            
            runUpdates([.setNext(name: waypoint, new: nil)])
        }
    }
    
    @IBAction func clearRoute(_ sender: Any) {
        route.clear()
        graphicsView.graphics.forEach { (graphic) in
            if !(graphic is Crosshairs) {
                self.graphicsView.remove(graphic)
            }
        }
    }
    
    // MARK:- Instigating route updates
    func instigateSelectionUpdate(newSelection waypointName: String?) {
        
        var updates = [RouteUpdate]()
        
        if let oldSelection = selection {
            updates.append(.deselect(name: oldSelection.name))
        }
        
        if let name = waypointName {
            updates.append(.select(name: name))
        }
        
        runUpdates(updates)
    }

    func instigateRerouting(set waypoint¹: String, toFollow waypoint⁰: String) {
        var updates = [RouteUpdate]()
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: waypoint¹) {
            updates.append(.setNext(name: previous, new: nil))
        }

        updates.append(.setNext(name: waypoint⁰, new: waypoint¹))
        if let selection = selection?.name {
            updates.append(.deselect(name: selection))
        }
        updates.append(.select(name: waypoint¹))
        runUpdates(updates)
    }
    
    func instigateInsertion(on arrow: Arrow) {
        
        guard let waypoint = self.waypoint(for: arrow) else {
            fatalError("failed to find arrow in <arrows>")
        }
        guard let next = route.nameOfWaypointFollowing(waypointNamed: waypoint) else {
            fatalError("found arrow for \(waypoint), but model reports no next")
        }
        
        var updates = [RouteUpdate]()
        if let selection = selection?.name {
            updates.append(.deselect(name: selection))
        }
        updates.append(.setNext(name: waypoint, new: nil))
        let pt⁰ = route.location(ofWaypointNamed: waypoint)
        let pt¹ = route.location(ofWaypointNamed: next)
        let midpoint = pt⁰.midpoint(pt¹)
        let newName = autoName()
        updates.append(.create(name: newName, location: midpoint))
        updates.append(.setNext(name: waypoint, new: newName))
        updates.append(.setNext(name: newName, new: next))
        updates.append(.select(name: newName))
        runUpdates(updates)
    }
    
    func instigateRemoval(of waypoint: String) {
        var updates = [RouteUpdate]()
        if let selection = self.selection, selection.name == waypoint {
            updates.append(.deselect(name: waypoint))
        }
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: waypoint) {
            updates.append(.setNext(name: previous, new: nil))
        }
        if let _ = route.nameOfWaypointFollowing(waypointNamed: waypoint) {
            updates.append(.setNext(name: waypoint, new: nil))
        }
        updates.append(.remove(name: waypoint, location: route.location(ofWaypointNamed: waypoint)))
        runUpdates(updates)
    }
    
    func instigateExtension(from waypoint: String) {
        var updates = [RouteUpdate]()
        if let _ = route.nameOfWaypointFollowing(waypointNamed: waypoint) {
            updates.append(.setNext(name: waypoint, new: nil))
        }
        let newName = autoName()
        updates.append(.create(name: newName, location: crosshairs.center))
        updates.append(.setNext(name: waypoint, new: newName))
        updates.append(.deselect(name: waypoint))
        updates.append(.select(name: newName))
        runUpdates(updates)
    }
    
    func instigateCreationOfNewWaypoint() {
        let name = autoName()
        var updates = [RouteUpdate.create(name: name, location: crosshairs.center)]
        updates.append(RouteUpdate.select(name: name))
        runUpdates(updates)
    }
    
    // MARK:- Executing routes updates
    
    func executeCreation(of waypoint: String, at location: CGPoint) {
        route.add(waypointNamed: waypoint, at: location)
        let node = newNode(at: location, name: waypoint)
        graphicsView.add(node)
        nodes[waypoint] = node
    }
    
    func executeRemove(of waypoint: String) {
        assert(selection?.name != waypoint, "must deselect node before removing")
        guard let node = nodes.removeValue(forKey: waypoint) else {
            fatalError("no node named \(waypoint) in <nodes>")
        }
        
        graphicsView.remove(node)
        if let _ = route.nameOfWaypointFollowing(waypointNamed: waypoint) {
            guard let arrow = arrows.removeValue(forKey: waypoint) else {
                fatalError("expected key '\(waypoint)' in <arrows>")
            }
            graphicsView.remove(arrow)
        }
        
        route.remove(waypointNamed: waypoint)
    }
    
    func executeSelection(of waypoint: String) {
        guard let node = nodes[waypoint] else {
            fatalError("no node with name \(waypoint) found in <nodes>")
        }
        
        if !node.selected {
            node.selected = true
            self.selection = node
        }
    }
    
    func executeDeselection(of waypoint: String) {
        guard let node = nodes[waypoint] else {
            fatalError("no node with name \(waypoint) found in <nodes>")
        }
        
        if node.selected {
            node.selected = false
            self.selection = nil
        }
        
    }
    
    func executeRelocation(ofWaypoint waypoint: String, from: CGPoint, to: CGPoint, followingPan: Bool) {
        route.updateLocation(ofWaypointNamed: waypoint, to: to)
        
        if !followingPan {
            guard let node = nodes[waypoint] else {
                fatalError("key '\(waypoint)' does not appear in <nodes>")
            }
            relocateNode(node, translation: CGPoint(x: to.x - from.x, y: to.y - from.y))
        }
    }
    
    func executeSetNext(of waypoint⁰: String, to waypoint¹: String?) {

        let oldNext = route.nameOfWaypointFollowing(waypointNamed: waypoint⁰)
        if let _ = oldNext {
            guard let arrow = arrows.removeValue(forKey: waypoint⁰) else {
                fatalError("expected to find key '\(waypoint⁰)' in <arrows>")
            }
            graphicsView.remove(arrow)
        }
        
        
        if let newNext = waypoint¹ {
            guard let node⁰ = nodes[waypoint⁰] else {
                fatalError("expected to find key '\(waypoint⁰)' in <nodes>")
            }
            guard let node¹ = nodes[newNext] else {
                fatalError("expected to find key '\(newNext)' in <nodes>")
            }
            
            if let previous = route.nameOfWaypointPreceeding(waypointNamed: newNext) {
                guard let arrow = arrows.removeValue(forKey: previous) else {
                    fatalError("expected for find key '\(previous)' in <arrows>")
                }
                graphicsView.remove(arrow)
            }
            
            let arrow = newArrow(from: node⁰, to: node¹)
            arrows[waypoint⁰] = arrow
            graphicsView.add(arrow)
            route.setNext(ofWaypointNamed: waypoint⁰, toWaypointNamed: newNext)
        } else {
            route.unsetNext(ofWaypointNamed: waypoint⁰)
        }
    }
    
    
    // MARK:- Running Updates
    
    func runUpdates(_ updates: [RouteUpdate]) {
        var undos = [RouteUpdate]()
        
        for update in updates {
            switch update {
            
            case .create(let name, let location):
                executeCreation(of: name, at: location)
                undos.append(update.undone())
                
            case .select(let name):
                executeSelection(of: name)
                undos.append(update.undone())
                
            case .deselect(let name):
                executeDeselection(of: name)
                undos.append(update.undone())
                
            case .remove(let name, _):
                executeRemove(of: name)
                undos.append(update.undone())
                
            case .move(let name, let from, let to, let byPan):
                executeRelocation(ofWaypoint: name, from: from, to: to, followingPan: byPan)
                undos.append(update.undone())
                
            case .setNext(let name, let new):
                let oldNext = route.nameOfWaypointFollowing(waypointNamed: name)
                executeSetNext(of: name, to: new)
                undos.append(.setNext(name: name, new: oldNext))
            }
        }
        
        DispatchQueue.main.async {
            self.updateButtons()
        }
        
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.runUpdates(undos.reversed())
        })
    }
    


    
    
    // MARK:- Book-keeping
    
    var unicodePoint = UNICODE_CAP_A
    
    var panningGraphic: Graphic?
    
    var nodeLocationBeforePan: CGPoint?
    
    var nodes = [String:Node]()
    
    var arrows = [String: Arrow]()
    
    func updateButtons() {
        guard let undoManager = undoManager else {
            undoButton.isEnabled = false
            redoButton.isEnabled = false
            return
        }
        
        if undoManager.canUndo != undoButton.isEnabled {
            undoButton.isEnabled = !undoButton.isEnabled
        }
        if undoManager.canRedo != redoButton.isEnabled {
            redoButton.isEnabled = !redoButton.isEnabled
        }
    }
    
    // MARK:- Convenience
    
    var arrowUnderCursor: Arrow? {
        return graphicsView.graphics.first(where: { (graphic) -> Bool in
            return (graphic is Arrow) && graphic.contains(crosshairs.center)
        }) as? Arrow
    }
    
    var nodeUnderCursor: Node? {
        return graphicsView.graphics.first { (graphic) -> Bool in
            return graphic is Node && graphic.contains(crosshairs.center)
        } as? Node
    }
    
    func waypoint(for arrow: Arrow) -> String? {
        return arrows.first(where: {$1 === arrow})?.key
    }
    
    // MARK:- Execution Helpers
    
    func relocateNode(_ node: Node, translation: CGPoint) {
        relocateGraphic(node, translation: translation)
        
        if let next = route.nameOfWaypointFollowing(waypointNamed: node.name) {
            guard let arrow = arrows[node.name] else {
                fatalError("expected key '\(node.name)' in <arrows>")
            }
            guard let nextNode = nodes[next] else {
                fatalError("expected key '\(next)' in <nodes>")
            }
            setArrow(arrow, toPointFrom: node, to: nextNode)
        }
        
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: node.name) {
            guard let arrow = arrows[previous] else {
                fatalError("expected key '\(previous)' in <arrows>")
            }
            guard let previousNode = nodes[previous] else {
                fatalError("expected key '\(previous)' in <nodes>")
            }
            setArrow(arrow, toPointFrom: previousNode, to: node)
        }
    }
    
    func relocateGraphic(_ graphic: Graphic, translation: CGPoint) {
        let oldFrame = graphic.frame
        let newCenter = CGPoint(x: graphic.center.x + translation.x, y: graphic.center.y + translation.y)
        graphic.center = newCenter
        graphicsView.setNeedsDisplay(oldFrame.union(graphic.frame))
    }
    
    func calculateCoordinates(ofArrowFrom from: Node, to: Node) -> (start: CGPoint, end: CGPoint) {
        guard from.center.distance(to: to.center) > nodeRadius * 2 + arrowInset * 2 else {
            return (.zero, .zero)
        }
        
        let line = LineSector(start: from.center, end: to.center)
        let d1 = nodeRadius + arrowInset
        let d2 = from.center.distance(to: to.center) - (nodeRadius + arrowInset)
        
        var start = line.point(distanceFromOrigin: d1)
        var end = line.point(distanceFromOrigin: d2)
        
        
        if route.circularRelationshipExistsBetween(waypointNamed: from.name, and: to.name) {
            let insetLine = LineSector(start: start, end: end)
            let offsetLines = insetLine.parallelLineSectors(offset: 15)
            start = offsetLines.0.start
            end = offsetLines.0.end
        }
        
        return (start, end)
    }
    
    func setArrow(_ arrow: Arrow, toPointFrom from: Node, to: Node) {
        assert(graphicsView.graphics.contains(where: { $0 === arrow }))
        let oldFrame = arrow.frame
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        arrow.update(start: pts.start, end: pts.end)
        graphicsView.setNeedsDisplay(oldFrame.union(arrow.frame))
    }
    
    func move(_ graphic: Graphic, to point: CGPoint) {
        if graphic is Crosshairs {
            graphicsView.setNeedsDisplay(graphic.frame)
            graphic.center = point
            graphicsView.setNeedsDisplay(graphic.frame)
        }
    }
    

    
    // MARK:- Creating nodes, arrows, names etc
    
    func autoName() -> String {
        let name = String(Unicode.Scalar(unicodePoint)!)
        unicodePoint += 1
        return name
    }
    
    func newNode(at centerpoint: CGPoint, name: String) -> Node {
        let node = Node(center: centerpoint, radius: nodeRadius, fill: .red, stroke: .clear, name: name)
        node.center = centerpoint
        return node
    }
    
    func newArrow(from: Node, to: Node) -> Arrow {
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        return Arrow(start: pts.start, end: pts.end)
    }
    

    // MARK:- Debugging
    
    func describeGraphicsView() {
        for (index, graphic) in graphicsView.graphics.enumerated() {
            if let node = graphic as? Node {
                print("\(index): \(node.name)(\(self.zone(containing: node.center)))")
            }
        }
    }
    
    // MARK:- Testing Machinery
    
    lazy var testsSummaryController: TestsSummaryController = {
        let testsSummaryController = TestsSummaryController()
        testsSummaryController.routeViewController = self
        return testsSummaryController
    }()
    
    func prepareForTesting() {
        installTestSummaryView()
        testsSummaryController.uiBot = uiBot
    }
    
    func installTestSummaryView() {
        let nib = UINib(nibName: "TestsSummaryView", bundle: nil)
        let _ = nib.instantiate(withOwner: testsSummaryController, options: nil)
        let testsSummaryView = testsSummaryController.view!
        let container = UIView()
        container.addSubview(testsSummaryView)
        view.addSubview(container)
        NSLayoutConstraint.fitSubviewIntoSuperview(subview: testsSummaryView)
        
        // Shadow the container
        let shadowLayer = CAShapeLayer()
        shadowLayer.shadowColor = UIColor.darkGray.cgColor
        shadowLayer.shadowOffset = .zero
        shadowLayer.shadowOpacity = 0.4
        shadowLayer.shadowRadius = 6
        shadowLayer.shadowPath = UIBezierPath(roundedRect: testsSummaryView.bounds.insetBy(dx: -3, dy: -3)
            , cornerRadius: 6).cgPath
        container.layer.insertSublayer(shadowLayer, at: 0)
        
        // Position the container
        let size = testsSummaryView.bounds.size
        let maxY = graphicsView.convert(graphicsView.bounds, from: view).maxY
        let origin = CGPoint(x: view.frame.midX - size.width * 0.5, y: maxY - 16 - size.height)
        container.frame = CGRect(origin: origin, size: size)
    }
    
    var tests = Bundle.main.url(forResource: "TestSix", withExtension: "plist")
    
    lazy var uiBot: UIBot = {
        let uiBot = UIBot(url: self.tests!, delegate: self.testsSummaryController, dataSource: self)
        return uiBot
    }()
}


// MARK:- Testing extension

extension RouteViewController: UIBotDataSource {
    
    func uiBot(_ uiBot: UIBot, executeTestNamed testName: String, data: Any?) -> (pass: Bool, msg: String) {
        switch testName {
        case "COUNT_WAYPOINTS":
            return countWaypoints(expectedWaypoints: data as! Int)
        case "COUNT_ARROWS":
            return countArrows(expected: data as! Int)
        case "VALIDATE_ROUTE_NEXT":
            return validateRouteNext(diagram: data as! String)
        case "VALIDATE_ROUTE_PREVIOUS":
            return validateRoutePrevious(diagram: data as! String)
        case "VALIDATE_SELECTION":
            return validateSelection(expectedSelectionName: data as! String)
        case "VALIDATE_WAYPOINT_LOCATION":
            return validateWaypointLocation(data as! String)
        case "VALIDATE_ARROW_PRESENCE":
            return validateArrowPresence(waypointName: data as! String)
        case "VALIDATE_ARROW_ABSENCE":
            return validateArrowAbsence(waypointName: data as! String)
        case "VALIDATE_ARROW_LOCATION":
            return validateArrowPosition(waypointName: data as! String)
        default:
            fatalError("\(testName) not recognised")
        }
    }
    
    
    func uiBot(_ uiBot: UIBot, operationIsTest operationName: String) -> Bool {
        return ["COUNT_WAYPOINTS", "COUNT_ARROWS", "DELETED_WAYPOINTS", "VALIDATE_ROUTE_NEXT", "VALIDATE_ROUTE_PREVIOUS", "VALIDATE_SELECTION", "VALIDATE_WAYPOINT_LOCATION", "VALIDATE_ARROW_PRESENCE","VALIDATE_ARROW_ABSENCE", "VALIDATE_ARROW_LOCATION"].contains(operationName)
    }

    func uiBot(_ uiBot: UIBot, blockForOperationNamed operationName: String, operationData: Any) -> (() -> Void) {
        switch operationName {
            
        // Editing
        case "TAP_ADD":
            return tapAdd()
        case "TAP_REMOVE":
            return tapRemove()
        case "TAP_UNDO":
            return tapUndo()
        case "TAP_REDO":
            return tapRedo()
        case "TAP_EMPTY_ZONE":
            return self.tapEmptyZone()
        case "TAP_WAYPOINT":
            return tapWaypoint(named: operationData as! String)
        case "MOVE_CROSSHAIRS_TO_ZONE":
            return moveCrosshairsToZone(operationData as! Int)
        case "MOVE_WAYPOINT_TO_ZONE":
            return moveWaypointToZone(rawData: operationData as! NSDictionary)
        case "SET_CROSSHAIRS_ON_WAYPOINT":
            return setCrosshairsOnWaypoint(named: operationData as! String)
        case "SET_CROSSHAIRS_ON_ARROW":
            return setCrosshairsOnArrow(originatingAt: operationData as! String)

            
        default:
            fatalError("\(operationName) not recognised")
        }
    }
    
    func setCrosshairsOnWaypoint(named name: String) -> () -> Void {
        return {
            let node = self.graphicsView.node(named: name)
            self.move(self.crosshairs, to: node.center)
        }
    }
    
    func tapAdd() -> () -> Void {
        return {
            self.userTappedAdd(self)
        }
    }
    
    func tapRemove() -> () -> Void {
        return {
            self.userTappedRemove(self)
        }
    }
    
    func tapRedo() -> () -> Void {
        return {
            self.redo(self)
        }
    }
    
    func tapUndo() -> () -> Void {
        return {
            self.undo(self)
        }
    }
    
    func moveCrosshairsToZone(_ zone: Int) -> () -> Void {
        return {
            let pt = self.center(of: zone)
            self.move(self.crosshairs, to: pt)
        }
    }
    
    func tapWaypoint(named name: String) -> () -> Void {
        return {
            let node = self.graphicsView.node(named: name)
            self.handleTap(at: node.center)
        }
    }
    
    func setCrosshairsOnArrow(originatingAt waypointName: String) -> () -> Void {
        return {
            let next = self.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
            let pt⁰ = self.route.location(ofWaypointNamed: waypointName)
            let pt¹ = self.route.location(ofWaypointNamed: next)
            let midPoint = pt⁰.midpoint(pt¹)
            self.move(self.crosshairs, to: midPoint)
        }
    }
    
    func moveWaypointToZone(rawData: NSDictionary) -> () -> Void {
        return {
            let waypointName = rawData["waypoint"] as! String
            let zone = rawData["zone"] as! Int
            //self.move(waypointNamed: waypointName, to: self.center(of: zone))
        }
    }
    
    func tapEmptyZone() -> () -> Void {
        return {
            self.handleTap(at: self.center(of: NODE_FREE_ZONE))
        }
    }
    
    // MARK: Tests
    
    func countWaypoints(expectedWaypoints: Int) -> (Bool, String) {
        let pass: Bool
        let msg: String
        let actualWaypoints = route.numbeOfWaypoints
        let actualCircles = graphicsView.graphics.filter { $0 is Node }.count
        if actualWaypoints == expectedWaypoints {
            if actualCircles == actualWaypoints {
                pass = true
                msg = "Number of waypoints is \(expectedWaypoints)"
            } else {
                pass = false
                msg = "Number of waypoints is as expected \(expectedWaypoints), but number of circles on the graphicsView is not \(actualCircles)"
            }
        } else {
            pass = false
            msg = "Number of waypoints is \(actualWaypoints), not \(expectedWaypoints)"
        }
        return (pass, msg)
    }
    
    func countArrows(expected: Int) -> (Bool, String) {
        let graphicsCount = graphicsView.graphics.filter { $0 is Arrow}.count
        let mapCount = arrows.count
        let pass: Bool
        let msg: String
        if expected == mapCount {
            if expected == graphicsCount {
                pass = true
                msg = "number of arrows is \(expected)"
            } else {
                pass = false
                msg = "arrow-map contains expected number of arrows \(expected), but number graphics on graphicsView is reported as \(graphicsCount)"
            }
        } else {
            pass = false
            msg = "number of arrows in arrow map is \(mapCount), not \(expected)"
        }
        
        return (pass, msg)
    }
    

    func validateRouteNext(diagram: String) -> (Bool, String) {
        let comps = diagram.components(separatedBy: "→")
        let name = comps.first!
        var expectedNext = comps.last!
        var pass: Bool
        var msg: String
        if let actualNext = route.nameOfWaypointFollowing(waypointNamed: name) {
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
        return (pass, msg)
    }
    
    
    func validateRoutePrevious(diagram: String) -> (Bool, String) {
        var pass: Bool
        var msg: String
        let comps = diagram.components(separatedBy: "→")
        let expectedPrevious = comps.first!
        let name = comps.last!
        if expectedPrevious == "*" {
            if let actualPrevious = self.route.nameOfWaypointPreceeding(waypointNamed: name) {
                pass = false
                msg = "previous of \(name) is \(actualPrevious), not nil"
            } else {
                pass = true
                msg = "previous of \(name) is nil"
            }
        } else if let actualPrevious = self.route.nameOfWaypointPreceeding(waypointNamed: name) {
            pass = actualPrevious == expectedPrevious
            msg = pass ? "previous of \(name) is \(expectedPrevious)" : "previous of \(name) is \(actualPrevious), not \(expectedPrevious)"
        } else {
            pass = false
            msg = "previous of \(name) is nil, not \(expectedPrevious)"
        }
        return (pass, msg)
    }
    
    func validateSelection(expectedSelectionName: String) -> (Bool, String) {

        let pass: Bool
        let msg: String

        if expectedSelectionName == "*" {
            if let actualSelectionName = self.selection?.name {
                pass = false
                msg = "selection is \(actualSelectionName), not nil"
            } else {
                pass = true
                msg = "selection is nil"
            }
        } else if let selectionName = self.selection?.name {
            pass = selectionName == expectedSelectionName
            msg = pass ? "selection is \(expectedSelectionName)" : "selection is \(selectionName) not \(expectedSelectionName)"
        } else {
            pass = false
            msg = "selection is nil, not \(expectedSelectionName)"
        }
        return (pass, msg)
    }
    
    func validateWaypointLocation(_ waypointName: String) -> (Bool, String) {
        let routePoint = self.route.location(ofWaypointNamed: waypointName)
        let nodePoint = self.nodes[waypointName]!.center
        let pass: Bool
        let msg: String
        if nodePoint == routePoint {
            pass = true
            msg = "waypoint and corresponding node report same location (\(routePoint))"
        } else {
            pass = false
            msg = "waypoint location \(routePoint) (zone \(self.zone(containing: routePoint)) differs from node location \(nodePoint) (zone \(self.zone(containing: nodePoint))"
        }
        return (pass, msg)
    }
    
    
    func validateArrowPresence(waypointName: String) -> (Bool, String) {
        var pass: Bool
        var msg: String
        if let arrow = self.arrows[waypointName] {
            if let _ = self.graphicsView.graphics.first(where: {$0 === arrow}) {
                pass = true
                msg = "found valid arrow for \(waypointName)"
            } else {
                pass = false
                msg = "found arrow in arrow-map for \(waypointName), but arrow not present on graphicsView"
            }
        } else {
            pass = false
            msg = "no key '\(waypointName)' in arrow-map"
        }

        return (pass, msg)
    }
    
   func validateArrowAbsence(waypointName: String) -> (Bool, String) {
        let pass: Bool
        let msg: String
        if let arrow = self.arrows[waypointName] {
            pass = false
            if let _ = self.graphicsView.graphics.first(where: {$0 === arrow}) {
                msg = "\(waypointName) does have arrow in arrow-map, and this arrow is on the graphicsView"
            } else {
                msg = "\(waypointName) does have arrow in arrow-map, but this arrow is not present on the graphicsView"
            }
        } else {
            pass = true
            msg = "\(waypointName) does not appear as a key in arrow-map"
        }
        return (pass, msg)
    }
    
    func validateArrowPosition(waypointName: String) -> (Bool, String) {
        let pass: Bool
        let msg: String

        let arrow = self.arrows[waypointName]!

        let location⁰ = self.route.location(ofWaypointNamed: waypointName)
        let nextName = self.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
        let location¹ = self.route.location(ofWaypointNamed: nextName)
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

        assert(self.graphicsView.graphics.first(where: {$0 === arrow}) != nil)
        if arrow.contains(midpoint) && gradsOk {
            msg = "arrow emanating from \(waypointName) is correctly positioned"
            pass = true
        } else {
            msg = "arrow emanating from \(waypointName) is not correctly positioned"
            pass = false
        }
        return (pass, msg)
    }
    
    // MARK:- Working with zones
    
    private var zoneSize: CGSize {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = graphicsView.bounds.width / nCols
        let zoneHeight = graphicsView.bounds.height / nRows
        
        return CGSize(width: zoneWidth, height: zoneHeight)
    }
    
    private func origin(of zone: Int) -> CGPoint {
        
        let nCols = CGFloat(grid.columns)
        
        let (row, _) = modf(CGFloat(zone) / nCols)
        let col = CGFloat(zone) - (row * nCols)
        
        let minX = col * zoneSize.width
        let minY = row * zoneSize.height
        
        return CGPoint(x: minX, y: minY)
    }
    
    private func center(of zone: Int) -> CGPoint {
        let origin = self.origin(of: zone)
        return CGPoint(x: origin.x + zoneSize.width * 0.5, y: origin.y + zoneSize.height * 0.5)
    }
    
    private func zone(containing point: CGPoint) -> Int {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = graphicsView.bounds.width / nCols
        let zoneHeight = graphicsView.bounds.height / nRows
        
        let row = floor(point.y / zoneHeight)
        let col = floor(point.x / zoneWidth)
        
        return Int(row * nCols + col)
    }
}
