//
//  ViewController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 06/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit


let UNICODE_CAP_A = 65

let grid: (rows: Int, columns: Int) = (15, 8)


class RouteViewController: UIViewController {

    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    var nextName = UNICODE_CAP_A
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
                    undoManager?.registerUndo(withTarget: self, handler: { (rvc) in
                        rvc.move(node, to: locationBeforePan)
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
    
    func newNode(at centerpoint: CGPoint) -> Node {
        let name = String(Unicode.Scalar(nextName)!)
        let node = Node(center: centerpoint, radius: nodeRadius, fill: .red, stroke: .clear, name: name)
        node.center = centerpoint
        nextName += 1
        return node
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        _undoManager = UndoManager()
    }
    
    var testsSummaryController = TestsSummaryController()
    
    func prepareForTesting() {
        guard let testsUrl = self.tests else {
            fatalError("Failed to get tests")
        }
        installTestSummaryView()
        testsSummaryController.routeBot = routeBot
        
        routeBot.loadData(from: testsUrl)
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
    
    func addNode(to zone: Int) -> Node {
        let center = randomLocation(in: zone)
        let node = newNode(at: center)
        return node
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    
    
    var selection: Node?
    
    func updateSelection(to newSelection: Node?) {
        
        if let oldSelection = selection {
            oldSelection.selected = false
            canvas.setNeedsDisplay(oldSelection.frame)
        }
        
        if let newSelection = newSelection {
            newSelection.selected = true
            canvas.setNeedsDisplay(newSelection.frame)
        }
        
        selection = newSelection
    }
    
    @IBAction func userTapped(_ tap: UITapGestureRecognizer) {
        handleTap(at: tap.location(in: canvas))
    }
    
    func handleTap(at point: CGPoint) {
        let graphicsUnderPoint = canvas.graphics.filter({ $0.frame.contains(point) })
        
        guard !graphicsUnderPoint.contains(where: {$0 is Crosshairs}) else {
            updateSelection(to: nil)
            return
        }
        
        guard let node = graphicsUnderPoint.first(where: { $0 is Node }) as? Node, !node.selected else {
            updateSelection(to: nil)
            return
        }
        
        updateSelection(to: node)
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
                insertCirle(on: arrow)
            } else {
                addStandaloneNode()
            }
        case let (nil, selection?):
            extendRoute(from: selection)
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
        
        
        let newNode = self.newNode(at: crosshairs.center)
        
        route.add(waypointNamed: newNode.name, at: crosshairs.center)
        route.setNext(ofWaypointNamed: name, toWaypointNamed: newNode.name)
        route.setNext(ofWaypointNamed: newNode.name, toWaypointNamed: self.node(named: next).name)
        
        canvas.add(newNode)
        setArrow(arrow, toPointFrom: self.node(named: name), to: newNode)
        
        let newArrow = makeArrow(from: newNode, to: self.node(named: next))
        canvas.add(newArrow)
        arrows[newNode.name] = newArrow
        
        // Maybe a problem with this line when undoing insert??
        updateSelection(to: newNode)
        
        
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
        updateSelection(to: target)
        arrows[subject.name] = arrow
    }
    
    func extendRoute(from existingNode: Node) {
        let newNode = self.newNode(at: crosshairs.center)

        var arrow: Arrow!
        if let _ = route.nameOfWaypointFollowing(waypointNamed: existingNode.name), let existingArrow = arrows.removeValue(forKey: existingNode.name) {
            let dirty = existingArrow.frame
            setArrow(existingArrow, toPointFrom: existingNode, to: newNode)
            arrow = existingArrow
            canvas.setNeedsDisplay(dirty.union(existingArrow.frame))
        } else {
            arrow = makeArrow(from: existingNode, to: newNode)
            canvas.insert(arrow, below: crosshairs)
        }
        arrows[existingNode.name] = arrow
        
        // update the model
        route.add(waypointNamed: newNode.name, at: crosshairs.center)
        route.setNext(ofWaypointNamed: existingNode.name, toWaypointNamed: newNode.name)
        
        // update the view
        canvas.insert(newNode, below: crosshairs)
        updateSelection(to: newNode)
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
    
    func addStandaloneNode() {
        let node = newNode(at: crosshairs.center)
        
        // update the model
        route.add(waypointNamed: node.name, at: crosshairs.center)
        
        // update the view
        canvas.insert(node, below: crosshairs)
        updateSelection(to: node)
    }
    
    
    
    
    
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
    
    func addNode(at centerpoint: CGPoint) {
        let node = newNode(at: centerpoint)
        canvas.insert(node, below: crosshairs)

        selection = node
    }
    
    func describeCanvas() {
        for (index, graphic) in canvas.graphics.enumerated() {
            if let node = graphic as? Node {
                print("\(index): \(node.name)(\(self.zone(containing: node.center)))")
            }
        }
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
            updateSelection(to: nil)
        }
        canvas.remove(node)
        
        // update model
        route.remove(waypointNamed: node.name)
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
    
    lazy var routeBot: RouteBot = {
        let routeBot = RouteBot()
        routeBot.routeViewController = self
        routeBot.delegate = self.testsSummaryController
        return routeBot
    }()
    
    func move(_ graphic: Graphic, to point: CGPoint) {
        
        if graphic is Crosshairs {
            canvas.setNeedsDisplay(graphic.frame)
            graphic.center = point
            canvas.setNeedsDisplay(graphic.frame)
        } else if let circle = graphic as? Node {
            let originalLocation = circle.center
            canvas.setNeedsDisplay(circle.frame)
            
            route.updateLocation(ofWaypointNamed: circle.name, to: point)
            circle.center = point
            
            canvas.setNeedsDisplay(circle.frame)
            
            if let nextName = route.nameOfWaypointFollowing(waypointNamed: circle.name), let arrow = arrows[circle.name] {
                // arrow pointing from moved waypoint
                canvas.setNeedsDisplay(arrow.frame)
                
                let nextNode = self.node(named: nextName)
                let (start, end) = calculateCoordinates(ofArrowFrom: circle, to: nextNode)
                arrow.update(start: start, end: end)
                
                canvas.setNeedsDisplay(arrow.frame)
            }
            
            if let previousName = route.nameOfWaypointPreceeding(waypointNamed: circle.name), let arrow = arrows[previousName] {
                // arrow pointing to moved waypoint
                canvas.setNeedsDisplay(arrow.frame)
                
                let previousNode = self.node(named: previousName)
                let (start, end) = calculateCoordinates(ofArrowFrom: previousNode, to: circle)
                arrow.update(start: start, end: end)
                
                canvas.setNeedsDisplay(arrow.frame)
            }
            
            undoManager?.registerUndo(withTarget: self, handler: { (rvc) in
                rvc.move(circle, to: originalLocation)
            })
            
        }
        
        
        
    }
    
}

