//
//  ViewController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 06/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

let CIRCLE_FREE_ZONE = 0
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
    
    @IBOutlet weak var graphicsViewContainer: UIView!
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.tintColor = .lightGray
        crosshairs = Crosshairs(center: CGPoint(x: graphicsView.bounds.midX, y: graphicsView.bounds.midY), size: CGSize(width: 120, height: 120))
        graphicsView.add(crosshairs)
        
       updateButtons()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let testsSummaryViewController = self.testsSummaryViewController else {
            fatalError("testsSummaryViewController is nil")
        }
        let uiBot = testsSummaryViewController.uiBot
        uiBot?.delegate = testsSummaryViewController
        uiBot?.dataSource = self
    }
    
    // MARK:- Variables (stored and computed)
    
    var route = Route()
    
    var crosshairs: Crosshairs!
    
    weak var selection: Circle? {
        didSet {
            if let old = oldValue {
                graphicsView.setNeedsDisplay(old.frame)
            }
            if let new = selection {
                graphicsView.setNeedsDisplay(new.frame)
            }
        }
    }
    
    let circleRadius = CGFloat(22.0)
    
    let arrowInset: CGFloat = 5
    
    let parallelArrowsOffset: CGFloat = 10
    
    private var _undoManager: UndoManager!
    
    override var undoManager: UndoManager? {
        return _undoManager
    }
    

    // MARK:- Outlets
    @IBOutlet weak var undoButton: UIBarButtonItem!
    
    @IBOutlet weak var redoButton: UIBarButtonItem!
    
    @IBOutlet weak var testViewTop: NSLayoutConstraint?
    
    @IBOutlet weak var viewBtmToTestViewBtm: NSLayoutConstraint?
    
    @IBOutlet weak var graphicsViewContainerBtmToViewBtm: NSLayoutConstraint!
    
    @IBOutlet var testViewContainer: UIView!
    
    @IBOutlet weak var lockView: UIImageView!
    
    // MARK:- Actions/Handling Actions
    
    @IBAction func userPannedOnGraphicsView(_ pan: UIPanGestureRecognizer) {
        guard mode == .user else { return }
        
        switch pan.state {
            
        case .began:
            let pt = pan.location(in: graphicsView)
            if crosshairs.contains(pt) {
                panningGraphic = crosshairs
            } else if let circle = graphicsView.graphics.first(where: { (graphic) -> Bool in
                graphic is Circle && graphic.contains(pt)
            }) as? Circle {
                panningGraphic = circle
                circleLocationBeforePan = circle.center
            }
            
        case .changed:
            
            if let circle = panningGraphic as? Circle {
                relocateCircle(circle, translation: pan.translation(in: graphicsView))
            } else if let crosshairs = panningGraphic as? Crosshairs {
                relocateGraphic(crosshairs, translation: pan.translation(in: graphicsView))
            }
            
            pan.setTranslation(CGPoint.zero, in: graphicsView)
            
        case .ended:
            if let circle = panningGraphic as? Circle, let initialLocation = circleLocationBeforePan {
                runUpdates([.move(name: circle.label, from: initialLocation, to: circle.center, byPan: true)])
            }
            circleLocationBeforePan = nil
            panningGraphic = nil

        default:
            break
        }
    }
    
    @IBAction func userTapped(_ tap: UITapGestureRecognizer) {
        guard mode == .user else { return }
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
        
        guard let circle = graphicsUnderPoint.first(where: { $0 is Circle }) as? Circle, !circle.selected else {
            /* Tap on selected circle deselects it */
            instigateSelectionUpdate(newSelection: nil)
            return
        }
        
        instigateSelectionUpdate(newSelection: circle.label)
    }
    
    @IBAction func undo(_ sender: Any) {
        guard mode == .user else { return }
        
        undoManager?.undo()
    }
    @IBAction func redo(_ sender: Any) {
        guard mode == .user else { return }
        
        undoManager?.redo()
    }
    
    @IBAction func userTappedAdd(_ sender: Any) {
        guard mode == .user else { return }
        
        switch (circleUnderCursor, selection) {
        case (nil, nil):
            if let arrow = arrowUnderCursor {
                instigateInsertion(on: arrow)
            } else {
                instigateCreationOfNewWaypoint()
            }
        case let (nil, selection?):
            instigateExtension(from: selection.label)
        case let (circleUnderCursor?, selection?):
            instigateRerouting(set: circleUnderCursor.label, toFollow: selection.label)
        default:
            break
        }
    }
    
    @IBAction func userTappedRemove(_ sender: Any) {
        guard mode == .user else { return }
        
        if let waypoint = circleUnderCursor?.label {
            instigateRemoval(of: waypoint)
        } else if let arrow = arrowUnderCursor {
            guard let (waypoint, _) = arrows.first(where: {$1 === arrow}) else {
                fatalError("can't find arrow in <arrows>")
            }
            
            runUpdates([.setNext(name: waypoint, new: nil)])
        }
    }
    
    @IBAction func userTappedTest(_ sender: Any) {
        if children.count > 0 {
            enterUserMode()
        } else {
            if route.numbeOfWaypoints > 0 {
                let alert = UIAlertController(title: "Re-entering Test Mode", message: "The current route will be destroyed; do you want to continue?", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { (_) in
                    self.enterTestMode()
                }))
                
                present(alert, animated: true, completion: nil)
            } else {
                enterTestMode()
            }
        }
    }
    

    
    @IBAction func clearRoute(_ sender: Any) {
        // Clearing model
        route.clear()
        
        // Clearing view/controller
        selection = nil
        arrows.removeAll()
        circles.removeAll()
        undoManager?.removeAllActions()
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
            updates.append(.deselect(name: oldSelection.label))
        }
        
        if let name = waypointName {
            updates.append(.select(name: name))
        }
        
        runUpdates(updates)
    }
    
    
    
    func instigateRerouting(set waypoint¹: String, toFollow waypoint⁰: String) {
        if let existingNext = route.nameOfWaypointFollowing(waypointNamed: waypoint⁰), existingNext == waypoint¹ {
            // Duplicating
            return
        }
        
        var updates = [RouteUpdate]()
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: waypoint¹) {
            updates.append(.setNext(name: previous, new: nil))
        }

        updates.append(.setNext(name: waypoint⁰, new: waypoint¹))
        if let selection = selection?.label {
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
        if let selection = selection?.label {
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
        if let selection = self.selection, selection.label == waypoint {
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
        let circle = newCircle(at: location, label: waypoint)
        graphicsView.add(circle)
        circles[waypoint] = circle
    }
    
    func executeRemove(of waypoint: String) {
        assert(selection?.label != waypoint, "must deselect circle before removing")
        guard let circle = circles.removeValue(forKey: waypoint) else {
            fatalError("no circle named \(waypoint) in <circles>")
        }
        
        graphicsView.remove(circle)
        if let _ = route.nameOfWaypointFollowing(waypointNamed: waypoint) {
            guard let arrow = arrows.removeValue(forKey: waypoint) else {
                fatalError("expected key '\(waypoint)' in <arrows>")
            }
            graphicsView.remove(arrow)
        }
        
        route.remove(waypointNamed: waypoint)
    }
    
    func executeSelection(of waypoint: String) {
        guard let circle = circles[waypoint] else {
            fatalError("no circle with label \(waypoint) found in <circles>")
        }
        
        if !circle.selected {
            circle.selected = true
            self.selection = circle
        }
    }
    
    func executeDeselection(of waypoint: String) {
        guard let circle = circles[waypoint] else {
            fatalError("no circle with name \(waypoint) found in <circles>")
        }
        
        if circle.selected {
            circle.selected = false
            self.selection = nil
        }
        
    }
    
    func executeRelocation(ofWaypoint waypoint: String, from: CGPoint, to: CGPoint, followingPan: Bool) {
        route.updateLocation(ofWaypointNamed: waypoint, to: to)
        
        if !followingPan {
            guard let circle = circles[waypoint] else {
                fatalError("key '\(waypoint)' does not appear in <circles>")
            }
            relocateCircle(circle, translation: CGPoint(x: to.x - from.x, y: to.y - from.y))
        }
    }
    
    
    func endRelationship(from waypoint⁰: String, to waypoint¹: String) {
        guard let arrow = arrows.removeValue(forKey: waypoint⁰) else {
            fatalError("expected to find key '\(waypoint⁰)' in <arrows>")
        }
        graphicsView.remove(arrow)
        if route.circularRelationshipExistsBetween(waypointNamed: waypoint⁰, and: waypoint¹) {
            guard let arrow = arrows[waypoint¹] else {
                fatalError("expected to find key '\(waypoint⁰)' in <arrows>")
            }
            guard let circle⁰ = circles[waypoint⁰], let circle¹ = circles[waypoint¹] else {
                fatalError("failed to find \(waypoint⁰) and/or \(waypoint¹) in <circles>")
            }
            let oldFrame = arrow.frame
            let pts = calculateCoordinates(ofArrowFrom: circle¹, to: circle⁰)
            arrow.update(start: pts.start, end: pts.end)
            graphicsView.setNeedsDisplay(oldFrame.union(arrow.frame))
        }
        route.unsetNext(ofWaypointNamed: waypoint⁰)
    }
    
    func createRelationship(from waypoint⁰: String, to waypoint¹: String) {
        guard let circle⁰ = circles[waypoint⁰] else {
            fatalError("expected to find key '\(waypoint⁰)' in <circles>")
        }
        guard let circle¹ = circles[waypoint¹] else {
            fatalError("expected to find key '\(waypoint¹)' in <circles>")
        }
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: waypoint¹) {
            endRelationship(from: previous, to: waypoint¹)
        }
        
        route.setNext(ofWaypointNamed: waypoint⁰, toWaypointNamed: waypoint¹)
        if route.circularRelationshipExistsBetween(waypointNamed: waypoint⁰, and: waypoint¹) {
            representCircularRelationshipBetween(waypoint⁰, and: waypoint¹)
        } else {
            let arrow = newArrow(from: circle⁰, to: circle¹)
            arrows[waypoint⁰] = arrow
            graphicsView.add(arrow)
        }
    }
    
    func executeSetNext(of waypoint⁰: String, to waypoint¹: String?) {
        
        let oldNext = route.nameOfWaypointFollowing(waypointNamed: waypoint⁰)
        guard oldNext != waypoint¹ else {
            // relationship already exists
            return
        }
        
        if let _ = oldNext {
            endRelationship(from: waypoint⁰, to: oldNext!)
        }
        
        if let newNext = waypoint¹ {
            createRelationship(from: waypoint⁰, to: newNext)
        }
    }
    
    
    
    func representCircularRelationshipBetween(_ waypoint⁰: String, and waypoint¹: String) {
        
        var ⁰To¹: Arrow
        var ¹To⁰: Arrow
        
        if let arrow = arrows[waypoint⁰] {
            ⁰To¹ = arrow
            graphicsView.setNeedsDisplay(arrow.frame)
        } else {
            ⁰To¹ = newArrow(from: circles[waypoint⁰]!, to: circles[waypoint¹]!)
            arrows[waypoint⁰] = ⁰To¹
            graphicsView.add(⁰To¹)
        }
        
        if let arrow = arrows[waypoint¹] {
            ¹To⁰ = arrow
            graphicsView.setNeedsDisplay(arrow.frame)
        } else {
            ¹To⁰ = newArrow(from: circles[waypoint¹]!, to: circles[waypoint⁰]!)
            arrows[waypoint¹] = ¹To⁰
            graphicsView.add(¹To⁰)
        }
        
        let standardArrowLine = LineSector(start: ⁰To¹.start, end: ⁰To¹.end)
        let offsetLines = standardArrowLine.parallelLineSectors(offset: parallelArrowsOffset)
        
        ⁰To¹.update(start: offsetLines.0.start, end: offsetLines.0.end)
        ¹To⁰.update(start: offsetLines.1.end, end: offsetLines.1.start)
        graphicsView.setNeedsDisplay(¹To⁰.frame.union(⁰To¹.frame))
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
    
    var circleLocationBeforePan: CGPoint?
    
    var circles = [String:Circle]()
    
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
    
    var circleUnderCursor: Circle? {
        return graphicsView.graphics.first { (graphic) -> Bool in
            return graphic is Circle && graphic.contains(crosshairs.center)
        } as? Circle
    }
    
    func waypoint(for arrow: Arrow) -> String? {
        return arrows.first(where: {$1 === arrow})?.key
    }
    
    // MARK:- Execution Helpers
    
    func relocateCircle(_ circle: Circle, translation: CGPoint) {
        relocateGraphic(circle, translation: translation)
        
        if let next = route.nameOfWaypointFollowing(waypointNamed: circle.label) {
            guard let arrow = arrows[circle.label] else {
                fatalError("expected key '\(circle.label)' in <arrows>")
            }
            guard let nextCircle = circles[next] else {
                fatalError("expected key '\(next)' in <circles>")
            }
            setArrow(arrow, toPointFrom: circle, to: nextCircle)
        }
        
        if let previous = route.nameOfWaypointPreceeding(waypointNamed: circle.label) {
            guard let arrow = arrows[previous] else {
                fatalError("expected key '\(previous)' in <arrows>")
            }
            guard let previousCircle = circles[previous] else {
                fatalError("expected key '\(previous)' in <circles>")
            }
            setArrow(arrow, toPointFrom: previousCircle, to: circle)
        }
    }
    
    func relocateGraphic(_ graphic: Graphic, translation: CGPoint) {
        let oldFrame = graphic.frame
        let newCenter = CGPoint(x: graphic.center.x + translation.x, y: graphic.center.y + translation.y)
        graphic.center = newCenter
        graphicsView.setNeedsDisplay(oldFrame.union(graphic.frame))
    }
    
    func calculateCoordinates(ofArrowFrom from: Circle, to: Circle) -> (start: CGPoint, end: CGPoint) {
        guard from.center.distance(to: to.center) > circleRadius * 2 + arrowInset * 2 else {
            return (.zero, .zero)
        }
        
        let line = LineSector(start: from.center, end: to.center)
        let d1 = circleRadius + arrowInset
        let d2 = from.center.distance(to: to.center) - (circleRadius + arrowInset)
        
        let start = line.point(distanceFromOrigin: d1)
        let end = line.point(distanceFromOrigin: d2)
        
        return (start, end)
    }
    
    func setArrow(_ arrow: Arrow, toPointFrom from: Circle, to: Circle) {
        assert(graphicsView.graphics.contains(where: { $0 === arrow }))
        let oldFrame = arrow.frame
        let waypoint⁰ = from.label
        let waypoint¹ = to.label
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        if route.circularRelationshipExistsBetween(waypointNamed: waypoint⁰, and: waypoint¹) {
            let centralLine = LineSector(start: pts.start, end: pts.end)
            let offsetLine = centralLine.parallelLineSectors(offset: parallelArrowsOffset).0
            arrow.update(start: offsetLine.start, end: offsetLine.end)
        } else {
            arrow.update(start: pts.start, end: pts.end)
        }
        graphicsView.setNeedsDisplay(oldFrame.union(arrow.frame))
    }
    
    func move(_ graphic: Graphic, to point: CGPoint) {
        if graphic is Crosshairs {
            graphicsView.setNeedsDisplay(graphic.frame)
            graphic.center = point
            graphicsView.setNeedsDisplay(graphic.frame)
        }
    }
    
    
    // MARK:- Creating circles, arrows, names etc
    
    func autoName() -> String {
        let name = String(Unicode.Scalar(unicodePoint)!)
        unicodePoint += 1
        return name
    }
    
    func newCircle(at centerpoint: CGPoint, label: String) -> Circle {
        let circle = Circle(center: centerpoint, radius: circleRadius, fill: .red, stroke: .clear, label: label)
        circle.center = centerpoint
        return circle
    }
    
    func newArrow(from: Circle, to: Circle) -> Arrow {
        let pts = calculateCoordinates(ofArrowFrom: from, to: to)
        return Arrow(start: pts.start, end: pts.end)
    }
    

    // MARK:- Seguing
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let testsSummaryViewController = segue.destination as? TestsSummaryViewController else {
            return
        }
        self.testsSummaryViewController = testsSummaryViewController
        
        
    }
    
    var testsSummaryViewController: TestsSummaryViewController! {
        didSet {
            testsSummaryViewController.routeViewController = self
            testsSummaryViewController.uiBot = UIBot(sequences: testSequences)
        }
    }
    
    // MARK:- Debugging
    
    func describeGraphicsView() {
        for (index, graphic) in graphicsView.graphics.enumerated() {
            if let circle = graphic as? Circle {
                print("\(index): \(circle.label)(\(self.zone(containing: circle.center)))")
            }
        }
    }
    
    // MARK:- Testing Machinery

    @IBOutlet weak var graphicsView: GraphicsView!
    
    lazy var testSequences: [UIBotSequence] = {
        var sequences = [UIBotSequence]()
        ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"].forEach { (number) in
            if let url = Bundle.main.url(forResource: "Test\(number)", withExtension: "plist") {
                sequences.append(UIBotSequence(from: url))
            }
        }
        return sequences
    }()
    
    enum Mode {
        case user
        case test
    }
    
    var mode = Mode.test
    
    // MARK:- Switching UI Modes
    
    func context(ofSize size: CGSize) -> CGContext? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(size.width) * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            return nil
        }
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        return context
    }
    
    func crosshairsImage() -> UIImage? {
        let x = self.crosshairs.frame.width * 0.5
        let y = self.crosshairs.frame.height * 0.5
        let crosshairs = Crosshairs(center: CGPoint(x: x, y: y), size: self.crosshairs.frame.size)
        
        guard let context = context(ofSize: crosshairs.frame.size) else {
            return nil
        }
        
        UIGraphicsPushContext(context)
        crosshairs.draw(in: context, rect: crosshairs.frame)
        if let cgImage = context.makeImage() {
            return UIImage(cgImage: cgImage)
        } else {
            return nil
        }
    }
    
    func graphicsViewImageForTransitionToMode(_ mode: Mode) -> UIImage? {
        let size: CGSize
        switch mode {
        case .user:
            let width = graphicsView.frame.width
            let height = testViewContainer.frame.maxY - graphicsView.frame.minY
            size = CGSize(width: width, height: height)
        case .test:
            size = graphicsView.bounds.size
        }
        
        guard let context = context(ofSize: size) else {
            return nil
        }
        UIGraphicsPushContext(context)
        graphicsView.graphics.forEach { (graphic) in
            if (mode == .user) || (mode == .test && !(graphic is Crosshairs)) {
                graphic.draw(in: context, rect: CGRect(origin: .zero, size: size))
            }
        }
        
        if let cgImage = context.makeImage() {
            return UIImage(cgImage: cgImage)
        } else {
            return nil
        }
    }
    
    func enterUserMode() {
        guard let testViewBottom = self.viewBtmToTestViewBtm else {
            fatalError("constaint 'testViewBottom' not set")
        }
        
        // 4. Slide out container
        testViewBottom.constant = -(testViewContainer.frame.height)

        UIView.animate(withDuration: 0.25, animations: {
            self.view.layoutIfNeeded()
            self.graphicsViewContainer.backgroundColor = .white
            self.lockView.alpha = 0.0
            self.navigationController?.navigationBar.tintColor = .systemBlue
            self.navigationItem.rightBarButtonItem?.image = #imageLiteral(resourceName: "Clipboard")
        }) { (_) in
            
            self.graphicsViewContainerBtmToViewBtm.isActive = true

            self.testsSummaryViewController.willMove(toParent: nil)
            self.testViewContainer.removeFromSuperview()
            self.testsSummaryViewController.removeFromParent()
            
            self.lockView.isHidden = true
            self.mode = .user
            
        }
    }
    
    func enterTestMode() {
        guard let graphicsViewImage = graphicsViewImageForTransitionToMode(.test), let crosshairsImage = crosshairsImage() else {
            // Plan-B???
            return
        }
        
        let graphicsViewImageView = UIImageView(image: graphicsViewImage)
        graphicsViewImageView.frame = graphicsView.bounds
        graphicsView.addSubview(graphicsViewImageView)
        
        let crosshairsImageView = UIImageView(image: crosshairsImage)
        crosshairsImageView.frame = self.crosshairs.frame
        graphicsView.addSubview(crosshairsImageView)
        
        graphicsView.graphics.forEach { $0.hidden = true }
        graphicsView.setNeedsDisplay()
        
        self.lockView.isHidden = false
        
        UIView.animate(withDuration: 0.25, animations: {
            graphicsViewImageView.alpha = 0
        }) { (_) in
            self.addChild(self.testsSummaryViewController)
            self.view.addSubview(self.testViewContainer)

            NSLayoutConstraint.activate([
                self.testViewContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 8),
                self.testViewContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -8),
                self.testViewContainer.topAnchor.constraint(equalTo: self.graphicsView.bottomAnchor, constant: 8)
            ])

            self.graphicsViewContainerBtmToViewBtm.isActive = false
            let constraint = self.view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: self.testViewContainer.bottomAnchor, constant: -self.testViewContainer.frame.height)
            constraint.isActive = true
            self.viewBtmToTestViewBtm = constraint
            self.testsSummaryViewController.didMove(toParent: self)
            self.testsSummaryViewController.uiBot.restart()
            
            self.view.layoutIfNeeded()
            constraint.constant = 8

            UIView.animate(withDuration: 0.25, animations: {
                self.view.layoutIfNeeded()
                crosshairsImageView.center = self.graphicsView.bounds.center
                self.lockView.alpha = 1.0
                self.graphicsViewContainer.backgroundColor = UIColor(named: "disabledBackground")
                self.navigationController?.navigationBar.tintColor = .lightGray
                self.navigationItem.rightBarButtonItem?.image = #imageLiteral(resourceName: "Female")
            }) { (_) in
                self.clearRoute(self)
                
                self.crosshairs.center = crosshairsImageView.center
                self.crosshairs.hidden = false
                self.graphicsView.setNeedsDisplay()
                
                crosshairsImageView.removeFromSuperview()
                
                self.mode = .test
            }
        }
    }
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
            let circle = self.graphicsView.circle(labeled: name)
            self.move(self.crosshairs, to: circle.center)
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
            let circle = self.graphicsView.circle(labeled: name)
            self.handleTap(at: circle.center)
        }
    }
    
    func setCrosshairsOnArrow(originatingAt waypointName: String) -> () -> Void {
        return {
            let next = self.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
            let pt⁰ = self.route.location(ofWaypointNamed: waypointName)
            let pt¹ = self.route.location(ofWaypointNamed: next)
            let midPoint: CGPoint
            if self.route.circularRelationshipExistsBetween(waypointNamed: waypointName, and: next) {
                let line = LineSector(start: pt⁰, end: pt¹)
                let arrowLine = line.parallelLineSectors(offset: self.parallelArrowsOffset).0
                midPoint = arrowLine.start.midpoint(arrowLine.end)
            } else {
                midPoint = pt⁰.midpoint(pt¹)
            }
            
            self.move(self.crosshairs, to: midPoint)
        }
    }
    
    func tapEmptyZone() -> () -> Void {
        return {
            self.handleTap(at: self.center(of: CIRCLE_FREE_ZONE))
        }
    }
    
    // MARK: Tests
    
    func countWaypoints(expectedWaypoints: Int) -> (Bool, String) {
        let pass: Bool
        let msg: String
        let actualWaypoints = route.numbeOfWaypoints
        let actualCircles = graphicsView.graphics.filter { $0 is Circle }.count
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
            if let actualSelectionName = self.selection?.label {
                pass = false
                msg = "selection is \(actualSelectionName), not nil"
            } else {
                pass = true
                msg = "selection is nil"
            }
        } else if let selectionName = self.selection?.label {
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
        let circlePoint = self.circles[waypointName]!.center
        let pass: Bool
        let msg: String
        if circlePoint == routePoint {
            pass = true
            msg = "waypoint and corresponding circle report same location (\(routePoint))"
        } else {
            pass = false
            msg = "waypoint location \(routePoint) (zone \(self.zone(containing: routePoint)) differs from circle location \(circlePoint) (zone \(self.zone(containing: circlePoint))"
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

        let midpoint: CGPoint
        let arrow = self.arrows[waypointName]!
        let nextName = self.route.nameOfWaypointFollowing(waypointNamed: waypointName)!
        
        let location⁰ = self.route.location(ofWaypointNamed: waypointName)
        let location¹ = self.route.location(ofWaypointNamed: nextName)
        
        if route.circularRelationshipExistsBetween(waypointNamed: waypointName, and: nextName) {
            let standardArrowLine = LineSector(start: location⁰, end: location¹)
            let offsetLines = standardArrowLine.parallelLineSectors(offset: parallelArrowsOffset)
            let arrowLine = offsetLines.0
            midpoint = arrowLine.start.midpoint(arrowLine.end)
        } else {
            midpoint = location⁰.midpoint(location¹)
        }
        
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
