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


class RouteViewController: UIViewController {

    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    var unicodePoint = UNICODE_CAP_A
    private var _undoManager: UndoManager!
    override var undoManager: UndoManager? {
        return _undoManager
    }
    
    let nodeRadius = CGFloat(22.0)
    let arrowInset: CGFloat = 5
    var canvas: Canvas {
        return view as! Canvas
    }
    
    var panningGraphic: Graphic?
    
    var nodeLocationBeforePan: CGPoint?
    
    func autoName() -> String {
        let name = String(Unicode.Scalar(unicodePoint)!)
        unicodePoint += 1
        return name
    }
    
    @IBAction func userPannedOnCanvas(_ pan: UIPanGestureRecognizer) {
        
        switch pan.state {
            
        case .began:
            let pt = pan.location(in: canvas)
            if crosshairs.contains(pt) {
                panningGraphic = crosshairs
            } else if let node = canvas.graphics.first(where: { (graphic) -> Bool in
                graphic is Node && graphic.contains(pt)
            }) as? Node {
                panningGraphic = node
                nodeLocationBeforePan = node.center
            }
            
        case .changed:
            
            if let node = panningGraphic as? Node {
                relocateNode(node, translation: pan.translation(in: canvas))
            } else if let crosshairs = panningGraphic as? Crosshairs {
                relocateGraphic(crosshairs, translation: pan.translation(in: canvas))
            }
            
            pan.setTranslation(CGPoint.zero, in: canvas)
            
        case .ended:
            if let node = panningGraphic as? Node {
                route.updateLocation(ofWaypointNamed: node.name, to: node.center)
                if let locationBeforePan = nodeLocationBeforePan {
                    undoManager?.setActionName("undo <pan>")
                    undoManager?.registerUndo(withTarget: self, handler: { (_) in
                        self.move(waypointNamed: node.name, to: locationBeforePan)
                    })
                }
            }
            nodeLocationBeforePan = nil
            panningGraphic = nil

        default:
            break
        }
    }
    
    func relocateGraphic(_ graphic: Graphic, translation: CGPoint) {
        let oldFrame = graphic.frame
        let newCenter = CGPoint(x: graphic.center.x + translation.x, y: graphic.center.y + translation.y)
        graphic.center = newCenter
        canvas.setNeedsDisplay(oldFrame.union(graphic.frame))
    }
    
    func relocateNode(_ node: Node, translation: CGPoint) {
        relocateGraphic(node, translation: translation)
        
        if let next = route.nameOfWaypointFollowing(waypointNamed: node.name), let arrow = arrows[node.name] {
            setArrow(arrow, toPointFrom: node, to: self.node(named: next))
        }
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: node.name), let arrow = arrows[previous] {
            setArrow(arrow, toPointFrom: self.node(named: previous), to: node)
        }
    }
    
    func newNode(at centerpoint: CGPoint, name: String) -> Node {
        let node = Node(center: centerpoint, radius: nodeRadius, fill: .red, stroke: .clear, name: name)
        node.center = centerpoint
        return node
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _undoManager = UndoManager()
    }
    
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
        let maxY = canvas.convert(canvas.bounds, from: view).maxY
        let origin = CGPoint(x: view.frame.midX - size.width * 0.5, y: maxY - 16 - size.height)
        container.frame = CGRect(origin: origin, size: size)
    }
    
    
    var crosshairs: Crosshairs!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        crosshairs = Crosshairs(center: CGPoint(x: canvas.bounds.midX, y: canvas.bounds.maxX), size: CGSize(width: 120, height: 120))
        canvas.add(crosshairs)
        prepareForTesting()
        updateButtons()
    }
    

    func randomLocation(in zone: Int) -> CGPoint {
        
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = view.bounds.width / nCols
        let zoneHeight = view.bounds.height / nRows
        
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
        
        let zoneWidth = canvas.bounds.width / nCols
        let zoneHeight = canvas.bounds.height / nRows
        
        let row = floor(point.y / zoneHeight)
        let col = floor(point.x / zoneWidth)
        
        return Int(row * nCols + col)
    }
    
    var undos = [String]() {
        didSet {
//            print("undo stack: \(undos)")
        }
    }
    

    func updateButtons() {
        guard let undoManager = undoManager else {
            undoButton.isEnabled = false
            redoButton.isEnabled = false
            return
        }
        
//        if undoManager.canUndo != undoButton.isEnabled {
//            undoButton.isEnabled = !undoButton.isEnabled
//        }
//        if undoManager.canRedo != redoButton.isEnabled {
//            redoButton.isEnabled = !redoButton.isEnabled
//        }
    }
    
    
    weak var selection: Node?
    
    func updateSelection(to waypointName: String?, isUndoable: Bool) {
        
        var newSelection: Node?
        if let name = waypointName {
            newSelection = canvas.node(named: name)
        }
        
        let undoName = selection?.name
        
        if let oldSelection = selection {
            oldSelection.selected = false
            canvas.setNeedsDisplay(oldSelection.frame)
        }
        
        if let newSelection = newSelection {
            newSelection.selected = true
            canvas.setNeedsDisplay(newSelection.frame)
        }
        
        selection = newSelection
        
        guard isUndoable else {
            return
        }
        
        undoManager?.setActionName("undo updateSelection")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.updateSelection(to: undoName, isUndoable: true)
        })
        
    }
    
    @IBAction func userTapped(_ tap: UITapGestureRecognizer) {
        handleTap(at: tap.location(in: canvas))
    }
    
    func handleTap(at point: CGPoint) {
        let graphicsUnderPoint = canvas.graphics.filter({ $0.frame.contains(point) })
        
        guard !graphicsUnderPoint.contains(where: {$0 is Crosshairs}) else {
            updateSelection(to: nil, isUndoable: true)
            print("tap in crosshairs")
            return
        }
        
        guard let node = graphicsUnderPoint.first(where: { $0 is Node }) as? Node, !node.selected else {
            
            updateSelection(to: nil, isUndoable: true)
            return
        }
        
        updateSelection(to: node.name, isUndoable: true)
    }
    
    @IBAction func undo(_ sender: Any) {
        print(undoManager?.undoActionName ?? "-")
        undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        print("redoing: \(undoManager?.redoActionName ?? "-")")
        undoManager?.redo()
    }
    
    @IBAction func userTappedAdd(_ sender: Any) {
        switch (nodeUnderCursor, selection) {
        case (nil, nil):
            if let arrow = arrowUnderCursor {
                insertCirle(on: arrow)
            } else {
                
                addStandaloneNode(at: crosshairs.center, named: autoName())
            }
        case let (nil, selection?):
            
            extend(from: selection, to: crosshairs.center, withName: autoName())
        case let (nodeUnderCursor?, selection?):
            updateNext(of: selection, to: nodeUnderCursor)
        default:
            break
        }
    }
    
    func insertCirle(on arrow: Arrow) {
        guard let name = arrows.first(where: {$1 === arrow})?.key else {
            return
        }
        guard let next = route.nameOfWaypointFollowing(waypointNamed: name) else {
            return
        }
        
        
        let newNode = self.newNode(at: crosshairs.center, name: autoName())
        
        route.add(waypointNamed: newNode.name, at: crosshairs.center)
        route.setNext(ofWaypointNamed: name, toWaypointNamed: newNode.name)
        route.setNext(ofWaypointNamed: newNode.name, toWaypointNamed: self.node(named: next).name)
        
        canvas.add(newNode)
        setArrow(arrow, toPointFrom: self.node(named: name), to: newNode)
        
        let newArrow = makeArrow(from: newNode, to: self.node(named: next))
        canvas.add(newArrow)
        arrows[newNode.name] = newArrow
        
        // Maybe a problem with this line when undoing insert??
        updateSelection(to: newNode.name, isUndoable: true)
        
        
    }
    
    func updateNext(of subject: Node, to target: Node) {
        var spareArrows = [Arrow]()
        
        
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: target.name), let existingArrow = arrows.removeValue(forKey: previous) {
            spareArrows.append(existingArrow)
        }
        
        if let _ = route.nameOfWaypointFollowing(waypointNamed: subject.name), let existingArrow = arrows.removeValue(forKey: subject.name) {
            spareArrows.append(existingArrow)
        }
        
        // update model
        route.setNext(ofWaypointNamed: subject.name, toWaypointNamed: target.name)

        // Update view
        let dirty = spareArrows.reduce(CGRect.null) { $0.union($1.frame) }
        let arrow: Arrow
        if let existingArrow = spareArrows.popLast() {
            arrow = existingArrow
            spareArrows.forEach { canvas.remove($0)}
            setArrow(arrow, toPointFrom: subject, to: target)
            canvas.setNeedsDisplay(dirty.union(arrow.frame))
        } else {
            arrow = makeArrow(from: subject, to: target)
            canvas.insert(arrow, below: crosshairs)
        }
        updateSelection(to: target.name, isUndoable: true)
        arrows[subject.name] = arrow
    }
    
    var arrows = [String: Arrow]()
    
    func node(named name: String) -> Node {
        return canvas.graphics.first { (graphic) -> Bool in
            if let node = graphic as? Node, node.name == name {
                return true
            } else {
                return false
            }
        } as! Node
    }
    
    func addStandaloneNode(at location: CGPoint, named name: String) {
        assert(selection == nil)
        let node = newNode(at: location, name: name)
        
        // update the model
        route.add(waypointNamed: node.name, at: location)
        
        // update the view
        canvas.insert(node, below: crosshairs)
        updateSelection(to: node.name, isUndoable: false)
        
        undoManager?.setActionName("undo <addStandaloneNode>")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.removeStandaloneNode(named: name)
        })
    }
    
    func removeStandaloneNode(named nodeName: String) {
        let node = canvas.node(named: nodeName)
        let location = route.location(ofWaypointNamed: nodeName)
        
        route.remove(waypointNamed: nodeName)
        canvas.remove(node)
        
        deletedWaypoints.append((name: node.name, location: location))
        if selection === node {
            updateSelection(to: nil, isUndoable: false)
        }
        
        undoManager?.setActionName("undo <removeStandaloneNode>")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            guard let rawWaypoint = self.deletedWaypoints.popLast() else {
                fatalError("requested undo, but <deletedWaypoints> is empty")
            }
            self.addStandaloneNode(at: rawWaypoint.location, named: rawWaypoint.name)
        })
    }
    
    
    func extend(from existingNode: Node, to location: CGPoint, withName name: String) {
        let newNode = self.newNode(at: location, name: name)
        let currentNext = route.nameOfWaypointFollowing(waypointNamed: existingNode.name)
        let existingName = existingNode.name
        
        route.add(waypointNamed: newNode.name, at: location)
        route.setNext(ofWaypointNamed: existingNode.name, toWaypointNamed: newNode.name)
        
        var arrow: Arrow!
        if let _ = currentNext, let existingArrow = arrows.removeValue(forKey: existingNode.name) {
            canvas.setNeedsDisplay(existingArrow.frame)
            setArrow(existingArrow, toPointFrom: existingNode, to: newNode)
            arrow = existingArrow
            canvas.setNeedsDisplay(arrow.frame)
        } else {
            arrow = makeArrow(from: existingNode, to: newNode)
            canvas.insert(arrow, below: crosshairs)
        }
        
        arrows[existingNode.name] = arrow
        
        canvas.insert(newNode, below: crosshairs)
        updateSelection(to: newNode.name, isUndoable: false)
        
        undoManager?.setActionName("undo <extend>")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.removeExtension(toNodeNamed: name, fromNodeNamed: existingName)
        })
    }
    
    func removeExtension(toNodeNamed name¹: String, fromNodeNamed name⁰: String) {
        guard route.nameOfWaypointFollowing(waypointNamed: name¹) == nil else {
            fatalError("<removeExtension> assumes node being removed has no next")
        }
        guard let arrow = arrows.removeValue(forKey: name⁰) else {
            fatalError("\(name⁰) is assumed to have a next, but can't find the associated arrow")
        }
        
        let location¹ = route.location(ofWaypointNamed: name¹)
        deletedWaypoints.append((name: name¹, location: location¹))
        
        let node¹ = canvas.node(named: name¹)
        canvas.remove(node¹)
        canvas.remove(arrow)
        
        route.remove(waypointNamed: name¹)
        
        updateSelection(to: name⁰, isUndoable: false)
        
        undoManager?.setActionName("undo <removeExtension>")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            guard let rawWaypoint = self.deletedWaypoints.popLast() else {
                fatalError("requested undo, but <deletedWaypoints> is empty")
            }
            
            guard let selection = self.selection, selection.name == name⁰ else {
                fatalError("need selection for extend operation")
            }
            guard selection.name == name⁰ else {
                fatalError("undoing <removeExtension>; expected selection name of \(name⁰)")
            }
            
            self.extend(from: selection, to: rawWaypoint.location, withName: rawWaypoint.name)
        })
    }
    

    func remove(_ node: Node) {
        
        // Update view
        if let _ = route.nameOfWaypointFollowing(waypointNamed: node.name) {
            if let arrow = arrows[node.name] {
                canvas.remove(arrow)
                arrows.removeValue(forKey: node.name)
            }
        }
        
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: node.name) {
            if let arrow = arrows[previous] {
                canvas.remove(arrow)
                arrows.removeValue(forKey: previous)
            }
        }
        
        if let selection = self.selection, node === selection {
            updateSelection(to: nil, isUndoable: true)
        }
        canvas.remove(node)
        
        // update model
        deletedWaypoints.append((name: node.name, location: node.center))
        route.remove(waypointNamed: node.name)
    }
    
    
    var deletedWaypoints = [(name: String, location: CGPoint)]()
    
    @IBAction func userTappedRemove(_ sender: Any) {
        
        if let node = nodeUnderCursor {
            remove(node)
        } else if let arrow = arrowUnderCursor {
            remove(arrow)
        }
    }

    var arrowUnderCursor: Arrow? {
        return canvas.graphics.first(where: { (graphic) -> Bool in
            return (graphic is Arrow) && graphic.contains(crosshairs.center)
        }) as? Arrow
    }
    
    var counter = 0

    func describeCanvas() {
        for (index, graphic) in canvas.graphics.enumerated() {
            if let node = graphic as? Node {
                print("\(index): \(node.name)(\(self.zone(containing: node.center)))")
            }
        }
    }
    
    func remove(_ arrow: Arrow) {
        
        canvas.remove(arrow)
        if let (name, _) = arrows.first(where: {$1 === arrow}) {
            arrows.removeValue(forKey: name)
            route.unsetNext(ofWaypointNamed: name)
        } else {
            fatalError("Internal inconsistency - asked to remove arrow that is not represented in arrows map.")
        }
    }
    
    var nodeUnderCursor: Node? {
        return canvas.graphics.first { (graphic) -> Bool in
            return graphic is Node && graphic.contains(crosshairs.center)
        } as? Node
    }
    
    var nodes: [Node] {
//        return view.subviews.filter { $0 is Node } as! [Node]
        return []
    }
    
    
    // Handling Arrows
    
    func makeArrow(from: Node, to: Node) -> Arrow {
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        return Arrow(start: pts.start, end: pts.end)
    }
    
    
    func setArrow(_ arrow: Arrow, toPointFrom from: Node, to: Node) {
        assert(canvas.graphics.contains(where: { $0 === arrow }))
        let oldFrame = arrow.frame
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        arrow.update(start: pts.start, end: pts.end)
        canvas.setNeedsDisplay(oldFrame.union(arrow.frame))
    }
    
    var route = Route()
    
    func calculateCoordinates(ofArrowFrom from: Node, to: Node) -> (start: CGPoint, end: CGPoint) {
        guard from.center.distance(to: to.center) > nodeRadius * 2 + arrowInset * 2 else {
            return (.zero, .zero)
        }
        
        let line = LineSector(start: from.center, end: to.center)
        let d1 = nodeRadius + arrowInset
        let d2 = from.center.distance(to: to.center) - (nodeRadius + arrowInset)
        
        var start = line.point(distanceFromOrigin: d1)
        var end = line.point(distanceFromOrigin: d2)
        
        if node(from, inCircularRelationshipWith: to) {
            let insetLine = LineSector(start: start, end: end)
            let offsetLines = insetLine.parallelLineSectors(offset: 15)
            start = offsetLines.0.start
            end = offsetLines.0.end
        }
        
        return (start, end)
    }
    
    @IBAction func clearRoute() {
        route.clear()
        canvas.graphics.forEach { (graphic) in
            if !(graphic is Crosshairs) {
                self.canvas.remove(graphic)
            }
        }
    }
    
    // MARK: Querying the model
    
    func node(_ node: Node, inCircularRelationshipWith other: Node) -> Bool {
        return route.circularRelationshipExistsBetween(waypointNamed: node.name, and: other.name)
    }
    
    @IBAction func userTappedTest(_ sender: Any) {
    }
    
    var tests = Bundle.main.url(forResource: "BotTests", withExtension: "plist")
    
    lazy var uiBot: UIBot = {
        let uiBot = UIBot(url: self.tests!, delegate: self.testsSummaryController, dataSource: self)
        return uiBot
    }()
    
    
    func move(waypointNamed waypointName: String, to point: CGPoint) {
        let node = canvas.node(named: waypointName)
        
        let originalLocation = node.center
        canvas.setNeedsDisplay(node.frame)
        
        route.updateLocation(ofWaypointNamed: waypointName, to: point)
        node.center = point
        
        canvas.setNeedsDisplay(node.frame)
        
        if let nextName = route.nameOfWaypointFollowing(waypointNamed: waypointName), let arrow = arrows[waypointName] {
            // arrow pointing from moved waypoint
            canvas.setNeedsDisplay(arrow.frame)
            
            let nextNode = self.node(named: nextName)
            let (start, end) = calculateCoordinates(ofArrowFrom: node, to: nextNode)
            arrow.update(start: start, end: end)
            
            canvas.setNeedsDisplay(arrow.frame)
        }
        
        if let previousName = route.nameOfWaypointPreceeding(waypointNamed: waypointName), let arrow = arrows[previousName] {
            // arrow pointing to moved waypoint
            canvas.setNeedsDisplay(arrow.frame)
            
            let previousNode = self.node(named: previousName)
            let (start, end) = calculateCoordinates(ofArrowFrom: previousNode, to: node)
            arrow.update(start: start, end: end)
            
            canvas.setNeedsDisplay(arrow.frame)
        }
        
        undoManager?.setActionName("undo <move>")
        undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.move(waypointNamed: waypointName, to: originalLocation)
            
        })
    }
    
    func move(_ graphic: Graphic, to point: CGPoint) {
        
        if graphic is Crosshairs {
            canvas.setNeedsDisplay(graphic.frame)
            graphic.center = point
            canvas.setNeedsDisplay(graphic.frame)
        }
    }
}


// Testing extension

extension RouteViewController: UIBotDataSource {
    
    func uiBot(_ uiBot: UIBot, executeTestNamed testName: String, data: Any?) -> (pass: Bool, msg: String) {
        switch testName {
        case "COUNT_WAYPOINTS":
            return countWaypoints(expectedWaypoints: data as! Int)
        case "COUNT_ARROWS":
            return countArrows(expected: data as! Int)
        default:
            fatalError()
        }
    }
    
    
    func uiBot(_ uiBot: UIBot, operationIsTest operationName: String) -> Bool {
        return ["COUNT_WAYPOINTS", "COUNT_ARROWS", "VALIDATE_ARROW_PRESENCE"].contains(operationName)
    }

    func uiBot(_ uiBot: UIBot, blockForOperationNamed operationName: String, operationData: Any) -> (() -> Void) {
        switch operationName {
            
        // Editing
        case "TAP_ADD":
            return tapAdd()
        case "TAP_REMOVE":
            return tapRemove()
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
            let node = self.canvas.node(named: name)
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
    
    func moveCrosshairsToZone(_ zone: Int) -> () -> Void {
        return {
            let pt = self.center(of: zone)
            self.move(self.crosshairs, to: pt)
        }
    }
    
    func tapWaypoint(named name: String) -> () -> Void {
        return {
            let node = self.canvas.node(named: name)
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
            self.move(waypointNamed: waypointName, to: self.center(of: zone))
        }
    }
    
    // TESTS
    
    func countWaypoints(expectedWaypoints: Int) -> (Bool, String) {
        let pass: Bool
        let msg: String
        let actualWaypoints = route.numbeOfWaypoints
        let actualCircles = canvas.graphics.filter { $0 is Node }.count
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
        return (pass, msg)
    }
    
    func countArrows(expected: Int) -> (Bool, String) {
        let graphicsCount = canvas.graphics.filter { $0 is Arrow}.count
        let mapCount = arrows.count
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
        
        return (pass, msg)
    }
    
    func deletedWaypoints(names: String) -> (Bool, String) {
        let expected = ConvertSeparatedStringToArray(names).sorted()
        let actual = deletedWaypoints.map({$0.name}).sorted()
        let pass = expected == actual
        let msg = pass ? "deleted waypoints array does consist of \(expected)" : "deleted waypoints array consists of \(actual), not \(expected)"
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
    
    
    // Working with zones
    
    private var zoneSize: CGSize {
        let nRows = CGFloat(grid.rows)
        let nCols = CGFloat(grid.columns)
        
        let zoneWidth = canvas.bounds.width / nCols
        let zoneHeight = canvas.bounds.height / nRows
        
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
}
