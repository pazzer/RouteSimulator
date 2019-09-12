//
//  ViewController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 06/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit


let UNICODE_CAP_A = 65
let CircleFreeZone = 0
let grid: (rows: Int, columns: Int) = (15, 8)

class ViewController: UIViewController {

    @IBOutlet weak var undoButton: UIBarButtonItem!
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    var nextName = UNICODE_CAP_A
    private var _undoManager: UndoManager!
    override var undoManager: UndoManager? {
        return _undoManager
    }
    
    let circleRadius = CGFloat(22.0)
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
            } else if let circle = canvas.graphics.first(where: { (graphic) -> Bool in
                graphic is Circle && graphic.contains(pt)
            }) as? Circle {
                panningGraphic = circle
            }
            
        case .changed:
            
            if let circle = panningGraphic as? Circle {
                relocateCircle(circle, translation: pan.translation(in: canvas))
            } else if let cursor = panningGraphic as? SquareCursor {
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
    
    func relocateCircle(_ circle: Circle, translation: CGPoint) {
        relocateGraphic(circle, translation: translation)
        if let next = route.next(of: circle.name!), let arrow = arrows[circle.name!] {
            setArrow(arrow, toPointFrom: circle, to: self.circle(named: next))
        }
        if let previous = route.previous(of: circle.name!), let arrow = arrows[previous] {
            setArrow(arrow, toPointFrom: self.circle(named: previous), to: circle)
        }
    }
    
    func addCirclesTo(zones: [Int]) {
        for zone in zones {
            assert(zone != CircleFreeZone)
            let circle = newCircle(at: randomLocation(in: zone))
            canvas.add(circle)
            
        }
    }
    
    func newCircle(at centerpoint: CGPoint) -> Circle {
        let name = String(Unicode.Scalar(nextName)!)
        let circle = Circle(center: centerpoint, radius: circleRadius, fill: .red, stroke: .clear, name: name)
        circle.center = centerpoint
        nextName += 1
        return circle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    var cursor: SquareCursor!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        cursor = SquareCursor(center: CGPoint(x: canvas.bounds.midX, y: canvas.bounds.maxX), size: CGSize(width: 120, height: 120))
        canvas.add(cursor)
        updateButtons()
    }
    
    func addCircle(to zone: Int) -> Circle {
        let center = randomLocation(in: zone)
        let circle = newCircle(at: center)
        return circle
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
    
    
    var selection: Circle?
    
    func updateSelection(to newSelection: Circle?) {
        
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
        
        guard let graphic = canvas.graphics.first(where: { $0.frame.contains(loc) }), let circle = graphic as? Circle else {
            updateSelection(to: nil)
            return
        }
        
        guard !circle.isLocked && !circle.selected else {
            return
        }
        
        updateSelection(to: circle)
        
    }
    
    @IBAction func undo(_ sender: Any) {
        undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        undoManager?.redo()
    }
    
    @IBAction func userTappedAdd(_ sender: Any) {
        switch (circleUnderCursor, selection) {
        case (nil, nil):
            addStandaloneCircle()
        case let (nil, selection?):
            extendRoute(from: selection)
        case let (circleUnderCursor?, selection?):
            updateNext(of: selection, to: circleUnderCursor)
        default:
            break
        }
    }
    
    func updateNext(of subject: Circle, to target: Circle) {
        var spareArrows = [Arrow]()
        
        if let previous = route.previous(of: target.name!), let existingArrow = arrows.removeValue(forKey: previous) {
            spareArrows.append(existingArrow)
        }
        
        if let _ = route.next(of: subject.name!), let existingArrow = arrows.removeValue(forKey: subject.name!) {
            spareArrows.append(existingArrow)
        }
        
        // update model
        route.setNext(of: subject.name!, to: target.name!)

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
        arrows[subject.name!] = arrow
        
    }
    

    
    func extendRoute(from existingCircle: Circle) {
        let newCircle = self.newCircle(at: cursor.center)
        
        var arrow: Arrow!
        if let _ = route.next(of: existingCircle.name!), let existingArrow = arrows.removeValue(forKey: existingCircle.name!) {
            let dirty = existingArrow.frame
            setArrow(existingArrow, toPointFrom: existingCircle, to: newCircle)
            arrow = existingArrow
            canvas.setNeedsDisplay(dirty.union(existingArrow.frame))
        } else {
            arrow = makeArrow(from: existingCircle, to: newCircle)
            canvas.insert(arrow, below: cursor)
        }
        arrows[existingCircle.name!] = arrow
        
        // update the model
        route.add(newCircle.name!)
        route.setNext(of: existingCircle.name!, to: newCircle.name!)
        
        // update the view
        canvas.insert(newCircle, below: cursor)
        updateSelection(to: newCircle)
        
        
    }
    
    var arrows = [String: Arrow]()
    
    func circle(named name: String) -> Circle {
        return canvas.graphics.first { (graphic) -> Bool in
            if let circle = graphic as? Circle, circle.name! == name {
                return true
            } else {
                return false
            }
        } as! Circle
    }
    
    func addStandaloneCircle() {
        let circle = newCircle(at: cursor.center)
        
        // update the model
        route.add(circle.name!)
        
        // update the view
        canvas.insert(circle, below: cursor)
        updateSelection(to: circle)
    }
    
    
    
    
    
    @IBAction func userTappedRemove(_ sender: Any) {
        
        if let circle = circleUnderCursor {
            remove(circle)
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
    
    func addCircle(at centerpoint: CGPoint) {
        let circle = newCircle(at: centerpoint)
        canvas.insert(circle, below: cursor)

        selection = circle
    }
    
    func describeCanvas() {
        for (index, graphic) in canvas.graphics.enumerated() {
            if let circle = graphic as? Circle {
                print("\(index): \(circle.name!)(\(self.zone(containing: circle.center)))")
            }
        }
    }
    
    func remove(_ circle: Circle) {
        
        // Update view
        if let _ = route.next(of: circle.name!) {
            if let arrow = arrows[circle.name!] {
                canvas.remove(arrow)
            }
        }
        
        if let previous = route.previous(of: circle.name!) {
            if let arrow = arrows[previous] {
                canvas.remove(arrow)
            }
        }
        
        if let selection = self.selection, circle === selection {
            updateSelection(to: nil)
        }
        canvas.remove(circle)
        
        // update model
        route.remove(circle.name!)
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
    
    var circleUnderCursor: Circle? {
        return canvas.graphics.first { (graphic) -> Bool in
            return graphic is Circle && graphic.contains(cursor.center)
        } as? Circle
    }
    
    var circles: [Circle] {
//        return view.subviews.filter { $0 is Circle } as! [Circle]
        return []
    }
    
    
    // Handling Arrows
    
    func makeArrow(from: Circle, to: Circle) -> Arrow {
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        return Arrow(start: pts.start, end: pts.end)
    }
    
    
    func setArrow(_ arrow: Arrow, toPointFrom from: Circle, to: Circle) {
        assert(canvas.graphics.contains(where: { $0 === arrow }))
        let oldFrame = arrow.frame
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        arrow.update(start: pts.start, end: pts.end)
        canvas.setNeedsDisplay(oldFrame.union(arrow.frame))
    }
    
    var route = Route()
    
    func calculateCoordinates(ofArrowFrom from: Circle, to: Circle) -> (start: CGPoint, end: CGPoint) {
        guard from.center.distance(to: to.center) > circleRadius * 2 + arrowInset * 2 else {
            return (.zero, .zero)
        }
        
        let line = LineSector(start: from.center, end: to.center)
        let d1 = circleRadius + arrowInset
        let d2 = from.center.distance(to: to.center) - (circleRadius + arrowInset)
        
        var start = line.point(distanceFromOrigin: d1)
        var end = line.point(distanceFromOrigin: d2)
        
        if circle(from, inCircularRelationshipWith: to) {
            let insetLine = LineSector(start: start, end: end)
            let offsetLines = insetLine.parallelLineSectors(offset: 15)
            start = offsetLines.0.start
            end = offsetLines.0.end
        }
        
        return (start, end)
    }
    
    // MARK: Querying the model
    
    func circle(_ circle: Circle, inCircularRelationshipWith other: Circle) -> Bool {
        guard let name = circle.name, let otherName = other.name else {
            fatalError("can't evaluate - found unnamed circle")
        }
        return route.circularRelationshipExistsBetween(name, and: otherName)
    }
}

