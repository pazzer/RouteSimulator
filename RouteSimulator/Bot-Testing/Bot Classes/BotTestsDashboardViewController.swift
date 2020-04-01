//
//  BotTestSummaryViewController.swift
//  QuickRoute
//
//  Created by Paul Patterson on 25/02/2020.
//  Copyright © 2020 paulpatterson. All rights reserved.
//

import UIKit

class BotTestsDashboardViewController: UIViewController, UIBotDelegate {
    
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
    
    var uiBot: UIBot!

    @IBAction func step(_ sender: Any) {
        do {
            try uiBot.step()
        } catch let error {
            print("step failed: \(error)")
        }
    }
    
    @IBAction func sectionStep(_ sender: Any) {
        do {
            try uiBot.step(to: .nextSection)
        } catch let error {
            print("section-step failed: \(error)")
        }
    }
    
    /*
     Completes all outstanding steps in the current sequence.
     */
    @IBAction func sequenceStep(_ sender: Any) {
        do {
            try uiBot.step(to: .end)
        } catch let error {
            print("sequence-step failed: \(error)")
        }
    }
    
    /*
     Jumps to the start of the next sequence, ignoring all outstanding steps in the current sequence
    */
    @IBAction func sequenceSkip(_ sender: Any) {
        do {
            try uiBot.loadNextSequence()
        } catch UIBotError.noSequencesRemaining {
            uiBot.restart()
            self.totalPasses = 0
            self.totalFails = 0
            completed = 0
        } catch {
            print("Unexpected Error")
        }
    }
    
    // MARK: UIBotDelegate
    
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named: String?) {
        NotificationCenter.default.post(name: .UIBotDidLoadSequence, object: uiBot)
        if index == 0 {
            reset()
        }
        
        leftOperation.text = nil
        middleOperation.text = nil
        rightOperation.text = nil
        
        sequenceFails = 0
        sequencePasses = 0
        
        currentTest.text = named
        currentFails.text = "\(0)"
        currentPasses.text = "\(0)"
        testNumber.text = "\(index + 1)."
        
        [step, sectionStep, sequenceStep].forEach { $0.isEnabled = true }
    }
    
    
    func uiBotExecutingBlocks(_ uiBot: UIBot) {
        self.step.isEnabled = false
        self.sectionStep.isEnabled = false
        self.sequenceStep.isEnabled = false
        self.sequenceSkip.isEnabled = false
    }
    
    func uiBotFinishedExecutingBlocks(_ uiBot: UIBot) {
        self.step.isEnabled = true
        self.sectionStep.isEnabled = true
        self.sequenceStep.isEnabled = true
        self.sequenceSkip.isEnabled = true
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
    
    var completed = 0 {
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
        
        let totalPasses = String(format: "%i %@", self.totalPasses, self.totalPasses == 1 ? "pass" : "passes")
        let totalFails = String(format: "%i %@", self.totalFails, self.totalFails == 1 ? "fail" : "fails")
        
        let passesAndFails = String(format: "%@, %@", totalPasses, totalFails)
        
        if uiBot.allSequencesComplete {
            summary = "All Complete (\(completed)): " + passesAndFails
        } else if completed == 0 {
            summary = "No Tests Completed"
        } else if completed == 1 {
            summary = "One Test Completed: " + passesAndFails
        } else {
            summary = "\(completed) Tests Completed: " + passesAndFails
        }
        
        mainSummary.text = summary
    }
    
    var skipped: Int = 0
    
    var setUpComplete = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !setUpComplete {
            divideButtons()
            setUpComplete = true
        }
        //reset()
    }

    func reset() {
        skipped = 0
        totalPasses = 0
        totalFails = 0
        sequencePasses = 0
        sequenceFails = 0
        completed = 0
        
        leftOperation.text = nil
        middleOperation.text = nil
        rightOperation.text = nil
        
        currentTest.text = nil
        testNumber.text = nil
        section = nil
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
