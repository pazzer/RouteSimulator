//
//  ViewController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 06/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit


let UNICODE_CAP_A = 65
let NodeFreeZone = 0
let grid: (rows: Int, columns: Int) = (15, 8)

class ViewController: UIViewController {

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
    
    @IBAction func userPannedOnCanvas(_ pan: UIPanGestureRecognizer) {
        
        switch pan.state {
            
        case .began:
            let pt = pan.location(in: canvas)
            if cursor.contains(pt) {
                panningGraphic = cursor
            } else if let node = canvas.graphics.first(where: { (graphic) -> Bool in
                graphic is Node && graphic.contains(pt)
            }) as? Node {
                panningGraphic = node
            }
            
        case .changed:
            
            if let node = panningGraphic as? Node {
                relocateNode(node, translation: pan.translation(in: canvas))
            } else if let cursor = panningGraphic as? Crosshairs {
                relocateGraphic(cursor, translation: pan.translation(in: canvas))
            }
            
            pan.setTranslation(CGPoint.zero, in: canvas)
            
        case .ended:
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
        if let next = route.next(of: node.name), let arrow = arrows[node.name] {
            setArrow(arrow, toPointFrom: node, to: self.node(named: next))
        }
        if let previous = route.previous(of: node.name), let arrow = arrows[previous] {
            setArrow(arrow, toPointFrom: self.node(named: previous), to: node)
        }
    }
    
    func addNodesTo(zones: [Int]) {
        for zone in zones {
            assert(zone != NodeFreeZone)
            let node = newNode(at: randomLocation(in: zone))
            canvas.add(node)
            
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
    }
    
    var cursor: Crosshairs!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cursor = Crosshairs(center: CGPoint(x: canvas.bounds.midX, y: canvas.bounds.maxX), size: CGSize(width: 120, height: 120))
        canvas.add(cursor)
        updateButtons()
    }
    
    func addNode(to zone: Int) -> Node {
        let center = randomLocation(in: zone)
        let node = newNode(at: center)
        return node
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        undos = []
        _undoManager = UndoManager()
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
        
        if undoManager.canUndo != undoButton.isEnabled {
            undoButton.isEnabled = !undoButton.isEnabled
        }
        if undoManager.canRedo != redoButton.isEnabled {
            redoButton.isEnabled = !redoButton.isEnabled
        }
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
        let loc = tap.location(in: canvas)
        
        guard let graphic = canvas.graphics.first(where: { $0.frame.contains(loc) }), let node = graphic as? Node else {
            updateSelection(to: nil)
            return
        }
        
        guard !node.isLocked && !node.selected else {
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
        guard let next = route.next(of: name) else {
            return
        }
        
        let newNode = self.newNode(at: cursor.center)
        canvas.add(newNode)
        setArrow(arrow, toPointFrom: self.node(named: name), to: newNode)
        
        let newArrow = makeArrow(from: newNode, to: self.node(named: next))
        canvas.add(newArrow)
        arrows[newNode.name] = newArrow
        
        route.add(newNode.name)
        route.setNext(of: name, to: newNode.name)
        route.setNext(of: newNode.name, to: self.node(named: next).name)
    }
    
    func updateNext(of subject: Node, to target: Node) {
        var spareArrows = [Arrow]()
        
        if let previous = route.previous(of: target.name), let existingArrow = arrows.removeValue(forKey: previous) {
            spareArrows.append(existingArrow)
        }
        
        if let _ = route.next(of: subject.name), let existingArrow = arrows.removeValue(forKey: subject.name) {
            spareArrows.append(existingArrow)
        }
        
        // update model
        route.setNext(of: subject.name, to: target.name)

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
            canvas.insert(arrow, below: cursor)
        }
        updateSelection(to: target)
        arrows[subject.name] = arrow
        
    }
    

    
    func extendRoute(from existingNode: Node) {
        let newNode = self.newNode(at: cursor.center)
        
        var arrow: Arrow!
        if let _ = route.next(of: existingNode.name), let existingArrow = arrows.removeValue(forKey: existingNode.name) {
            let dirty = existingArrow.frame
            setArrow(existingArrow, toPointFrom: existingNode, to: newNode)
            arrow = existingArrow
            canvas.setNeedsDisplay(dirty.union(existingArrow.frame))
        } else {
            arrow = makeArrow(from: existingNode, to: newNode)
            canvas.insert(arrow, below: cursor)
        }
        arrows[existingNode.name] = arrow
        
        // update the model
        route.add(newNode.name)
        route.setNext(of: existingNode.name, to: newNode.name)
        
        // update the view
        canvas.insert(newNode, below: cursor)
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
        let node = newNode(at: cursor.center)
        
        // update the model
        route.add(node.name)
        
        // update the view
        canvas.insert(node, below: cursor)
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
            return (graphic is Arrow) && graphic.contains(cursor.center)
        }) as? Arrow
    }
    
    var counter = 0
    
    func addNode(at centerpoint: CGPoint) {
        let node = newNode(at: centerpoint)
        canvas.insert(node, below: cursor)

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
        if let _ = route.next(of: node.name) {
            if let arrow = arrows[node.name] {
                canvas.remove(arrow)
            }
        }
        
        if let previous = route.previous(of: node.name) {
            if let arrow = arrows[previous] {
                canvas.remove(arrow)
            }
        }
        
        if let selection = self.selection, node === selection {
            updateSelection(to: nil)
        }
        canvas.remove(node)
        
        // update model
        route.remove(node.name)
    }
    
    func remove(_ arrow: Arrow) {
        
        canvas.remove(arrow)
        if let (name, _) = arrows.first(where: {$1 === arrow}) {
            arrows.removeValue(forKey: name)
            route.setNext(of: name, to: nil)
        } else {
            fatalError("Internal inconsistency - asked to remove arrow that is not represented in arrows map.")
        }
    }
    
    var nodeUnderCursor: Node? {
        return canvas.graphics.first { (graphic) -> Bool in
            return graphic is Node && graphic.contains(cursor.center)
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
    
    // MARK: Querying the model
    
    func node(_ node: Node, inCircularRelationshipWith other: Node) -> Bool {
        return route.circularRelationshipExistsBetween(node.name, and: other.name)
    }
}

