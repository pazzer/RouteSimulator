//
//  TestsSummaryController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

class TestsSummaryController: NSObject, RouteBotDelegate {

    

    
    
    //var routeViewController: RouteViewController!
    
    
    @IBOutlet var view: UIView!
    
    @IBOutlet weak var testNumber: UILabel!
    @IBOutlet weak var currentTest: UILabel!
    @IBOutlet weak var mainSummary: UILabel!
    @IBOutlet weak var currentFails: UILabel!
    @IBOutlet weak var currentPasses: UILabel!
    @IBOutlet weak var leftOperation: UILabel!
    @IBOutlet weak var middleOperation: UILabel!
    @IBOutlet weak var rightOperation: UILabel!
    @IBOutlet weak var step: UIButton!
    @IBOutlet weak var jump: UIButton!
    @IBOutlet weak var skip: UIButton!
    
    var routeBot: RouteBot!
    
    func setUp() {
        completed = 0
        step.addTarget(routeBot, action: #selector(RouteBot.step(_:)), for: .touchUpInside)
        jump.addTarget(routeBot, action: #selector(RouteBot.jump(_:)), for: .touchUpInside)
        skip.addTarget(routeBot, action: #selector(RouteBot.skip(_:)), for: .touchUpInside)
    }
    
    // MARK: RouteBotDelegate
    
    func routeBot(_ routeBot: RouteBot, loadedSequence index: Int, named: String?) {
        if index == 0 {
            setUp()
        }
        leftOperation.text = nil
        middleOperation.text = nil
        rightOperation.text = nil
        
        sequenceFails = 0
        sequencePasses = 0
        
        routeBot.routeViewController.clearRoute()
        routeBot.routeViewController.nextName = UNICODE_CAP_A
        
        currentTest.text = named
        currentFails.text = "\(0)"
        currentPasses.text = "\(0)"
        testNumber.text = "\(index + 1)."
        step.isHidden = false
        skip.isHidden = false
    }
    
    let testTextColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)
    
    func routeBot(_ routeBot: RouteBot, loadedOperation index: Int, named name: String, isTest: Bool) {
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = name
        leftOperation.textColor = isTest ? testTextColor : .black
        
        if index > 0 {
            skip.isHidden = true
        }
    }
    
    var completed: Int! {
        didSet {
            updateSummary()
        }
    }
    
    func routeBot(_ routeBot: RouteBot, didCompleteSequence index: Int, named name: String?) {
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = nil
        step.isHidden = true
        
        totalFails += sequenceFails
        totalPasses += sequencePasses
        
        completed += 1
    }
    
    func routeBotCompletedAllSequences(_ routeBot: RouteBot) {
        mainSummary.text = "All Tests Completed"
        [step, jump, skip].forEach({$0?.isHidden = true})
        [rightOperation, leftOperation, middleOperation, currentFails, currentPasses, testNumber, currentTest].forEach({ $0?.text = nil })
    }
    
    func routeBot(_ routeBot: RouteBot, evaluated operation: String, didPass: Bool, details: String?) {
        if didPass {
            sequencePasses += 1
        } else {
            sequenceFails += 1
        }
    }
    
    var sequencePasses = 0 {
        didSet {
            currentPasses.text = "\(sequencePasses)"
        }
    }
    
    var sequenceFails = 0 {
        didSet {
            currentFails.text = "\(sequenceFails)"
        }
    }
    
    var totalPasses = 0
    
    var totalFails = 0
    
    func routeBot(_ routeBot: RouteBot, isSkippingSequence index: Int, named name: String?) {
        skipped += 1
    }
    
    func updateSummary() {
        var summary: String!
        
        if completed == 0 {
            summary = "No Tests Completed"
        } else if completed == 1 {
            summary = "One Test Completed: \(totalPasses) passes, \(totalFails) fails."
        } else{
            summary = "\(completed!) Tests Completed: \(totalPasses) passes, \(totalFails) fails."
        }
        mainSummary.text = summary
    }
    
    var skipped: Int = 0
    
    
    
    
    
    
    
}
