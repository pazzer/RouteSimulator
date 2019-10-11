//
//  TestsSummaryController.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import UIKit

class TestsSummaryViewController: UIViewController, UIBotDelegate {
    
    @IBOutlet weak var testNumber: UILabel!
    @IBOutlet weak var currentTest: UILabel!
    
    @IBOutlet weak var mainSummary: UILabel!
    @IBOutlet weak var currentFails: UILabel!
    @IBOutlet weak var currentPasses: UILabel!
    @IBOutlet weak var sectionName: UILabel!
    @IBOutlet weak var leftOperation: UILabel!
    @IBOutlet weak var middleOperation: UILabel!
    @IBOutlet weak var rightOperation: UILabel!
    
    // Takes a single step forward
    @IBOutlet weak var step: UIButton!
    
    // Steps through all outstanding operations in the current section
    @IBOutlet weak var sectionStep: UIButton!
    
    // Steps through all outstanding operations in the current sequence
    @IBOutlet weak var sequenceStep: UIButton!
    
    // Jumps to the start of the next sequence, ignoring any outstanding steps in the current one
    @IBOutlet weak var sequenceSkip: UIButton!
    
    @IBOutlet weak var buttonStack: UIStackView!
    
    weak var routeViewController: RouteViewController!
    var uiBot: UIBot!

    @IBAction func step(_ sender: Any) {
        try! uiBot.step()
    }
    
    @IBAction func sectionStep(_ sender: Any) {
        try! uiBot.step(to: .nextSection)
    }
    
    /*
     Completes all outstanding steps in the current sequence.
     */
    @IBAction func sequenceStep(_ sender: Any) {
        try! uiBot.step(to: .end)
    }
    
    /*
     Jumps to the start of the next sequence, ignoring all outstanding steps in the current sequence
    */
    @IBAction func sequenceSkip(_ sender: Any) {
        do {
            try uiBot.loadNextSequence()
        } catch UIBotError.noSequencesRemaining {
            uiBot.reset()
            self.totalPasses = 0
            self.totalFails = 0
            completed = 0
        } catch {
            print("Unexpected Error")
        }
    }
    
    // MARK: UIBotDelegate
    
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named: String?) {        
        leftOperation.text = nil
        middleOperation.text = nil
        rightOperation.text = nil
        
        sequenceFails = 0
        sequencePasses = 0
        
        routeViewController.clearRoute(self)
        routeViewController.unicodePoint = UNICODE_CAP_A
        
        currentTest.text = named
        currentFails.text = "\(0)"
        currentPasses.text = "\(0)"
        testNumber.text = "\(index + 1)."
        
        [step, sectionStep, sequenceStep].forEach { $0.isEnabled = true }
    }
    
    
    let testTextColor = #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1)
    
    var section: String? {
        didSet {
            sectionName.text = self.section ?? "Section Name Unavailable"
        }
    }
    
    func uiBot(_ uiBot: UIBot, loadedOperation operationName: String, fromSection section: String?, operationIndex: Int, isTest: Bool) {
        
        if section != self.section {
            self.section = section
        }
        
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = operationName
        leftOperation.textColor = isTest ? testTextColor : .black
    }
    
    var completed: Int! {
        didSet {
            updateSummary()
        }
    }
    
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?, isLast: Bool) {
        
        rightOperation.text = middleOperation.text
        rightOperation.textColor = middleOperation.textColor
        
        middleOperation.text = leftOperation.text
        middleOperation.textColor = leftOperation.textColor
        
        leftOperation.text = nil
        
        [step, sectionStep, sequenceStep].forEach { $0?.isEnabled = false }
        
        totalFails += sequenceFails
        totalPasses += sequencePasses
        
        completed += 1
    }
    
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?) {
        
        if didPass {
            sequencePasses += 1
            leftOperation.textColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
        } else {
            sequenceFails += 1
            leftOperation.textColor = .red
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
        let passesAndFails = "\(totalPasses) passes, \(totalFails) fails."
        if uiBot.allSequencesComplete {
            summary = "All Complete (\(completed!)): " + passesAndFails
        } else if completed == 0 {
            summary = "No Tests Completed"
        } else if completed == 1 {
            summary = "One Test Completed: " + passesAndFails
        } else {
            summary = "\(completed!) Tests Completed: " + passesAndFails
        }
        
        mainSummary.text = summary
    }
    
    var skipped: Int = 0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        divideButtons()
        completed = 0
        
    }
    
    func divideButtons() {
        [step, sectionStep, sequenceStep].forEach { (btn) in
            let rect = btn!.convert(btn!.bounds, to: view)
            let dlvFrame = CGRect(x: rect.maxX - 1, y: buttonStack.frame.minY, width: 3, height: buttonStack.frame.height)
            let dlv = DashedLineView(frame: dlvFrame)
            dlv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(dlv)
        }
        
    }
    

}


