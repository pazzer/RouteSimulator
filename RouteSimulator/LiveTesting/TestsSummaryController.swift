//
//  TestsSummaryController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

class TestsSummaryController: NSObject, UIBotDelegate {
    
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
    @IBOutlet weak var sectionStep: UIButton!
    @IBOutlet weak var sequenceStep: UIButton!
    @IBOutlet weak var sequenceSkip: UIButton!
    @IBOutlet weak var buttonStack: UIStackView!
    
    weak var routeViewController: RouteViewController!
    var uiBot: UIBot!
    
    func setUp() {
        completed = 0
        divideButtons()
    }
    
    
    @IBAction func step(_ sender: Any) {
        guard !uiBot.allStepsComplete else {
            return
        }
        try! uiBot.step()
    }
    
    
    @IBAction func sectionStep(_ sender: Any) {
        guard !uiBot.allStepsComplete else {
            return
        }
        //try! uiBot.sectionStep()
    }
    
    /*
     Completes all outstanding steps in the current sequence.
     */
    @IBAction func sequenceStep(_ sender: Any) {
        //try! uiBot.sequenceStep()
//        if uiBot.allSequencesComplete {
//            uiBot.reset()
//        }
        //        if uiBot.allSequencesComplete {
        //            uiBot.reset()
        //        } else if uiBot.allStepsComplete {
        //            try! uiBot.loadNextSequence()
        //        } else {
        //            try! uiBot.sequenceStep()
        //        }
    }
    
    /*
     Jumps to the start of the next sequence, ignoring all outstanding steps in the current sequence
    */
    @IBAction func sequenceSkip(_ sender: Any) {
        
    }
    
    // MARK: UIBotDelegate
    
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named: String?) {
        if index == 0 {
            setUp()
        }
        leftOperation.text = nil
        middleOperation.text = nil
        rightOperation.text = nil
        
        sequenceFails = 0
        sequencePasses = 0
        
        routeViewController.clearRoute()
        routeViewController.unicodePoint = UNICODE_CAP_A
        
        currentTest.text = named
        currentFails.text = "\(0)"
        currentPasses.text = "\(0)"
        testNumber.text = "\(index + 1)."
        sectionStep.isHidden = false
        //skip.isHidden = false
    }
    
    let testTextColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)
    
    var section: String! {
        didSet {
            print("\tNEXT: \(self.section!)")
        }
    }
    
    func uiBot(_ uiBot: UIBot, loadedOperation operationName: String, fromSection section: String, operationIndex: Int, isTest: Bool) {
        
        if section != self.section {
            self.section = section
        }
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = operationName
        leftOperation.textColor = isTest ? testTextColor : .black
        
        if operationIndex > 0 {
            //skip.isHidden = true
        }
    }
    
    
    
    var completed: Int! {
        didSet {
            updateSummary()
        }
    }
    
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?) {
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = nil
        //step.isHidden = true
        //skip.isHidden = true
        
        totalFails += sequenceFails
        totalPasses += sequencePasses
        
        completed += 1
    }
    
    func uiBotCompletedAllSequences(_ uiBot: UIBot) {
        mainSummary.text = "All Tests Completed"
        //[step, jump, skip].forEach({$0?.isHidden = true})
        [rightOperation, leftOperation, middleOperation, currentFails, currentPasses, testNumber, currentTest].forEach({ $0?.text = nil })
    }
    
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?) {
        
        if didPass {
            sequencePasses += 1
            leftOperation.textColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
        } else {
            sequenceFails += 1
            leftOperation.textColor = .red
            print(details ?? "no details")
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
    
    func uiBot(_ uiBot: UIBot, isSkippingSequence index: Int, named name: String?) {
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
    
    
    func divideButtons() {
        guard let view = buttonStack.superview else {
            return
        }
    
        [step, sectionStep, sequenceStep].forEach { (btn) in
            let rect = btn!.convert(btn!.bounds, to: view)
            let dlvFrame = CGRect(x: rect.maxX - 1, y: buttonStack.frame.minY, width: 3, height: buttonStack.frame.height)
            let dlv = DashedLineView(frame: dlvFrame)
            dlv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(dlv)
        }
    }
    
    
    
    
}
