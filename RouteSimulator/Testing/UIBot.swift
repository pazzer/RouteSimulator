//
//  UIBot.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

enum UIBotError: Error {
    case sequenceIsComplete
    case allSequencesComplete
    case noSequencesRemaining
}

protocol UIBotDataSource {
    func uiBot(_ uiBot: UIBot, blockForOperationNamed operationName: String, operationData: Any) -> (() -> Void)
    func uiBot(_ uiBot: UIBot, operationIsTest operationName: String) -> Bool
    func uiBot(_ uiBot: UIBot, executeTestNamed testName: String, data: Any?) -> (pass: Bool, msg: String)
}

protocol UIBotDelegate {
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named name: String?)
    func uiBot(_ uiBot: UIBot, loadedOperation named: String, fromSection section: String?, operationIndex: Int, isTest: Bool)
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?, isLast: Bool)
    func uiBot(_ uiBot: UIBot, isSkippingSequence index: Int, named name: String?)
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?)
}

extension UIBotDelegate {
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named name: String?) { }
    func uiBot(_ uiBot: UIBot, loadedOperation named: String, fromSection section: String?, operationIndex: Int, isTest: Bool) { }
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?, isLast: Bool) { }
    func uiBot(_ uiBot: UIBot, isSkippingSequence index: Int, named name: String?) { }
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?) { }
}

class UIBot {
    
    init(url: URL, delegate: UIBotDelegate, dataSource: UIBotDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        
        let rawSequences = LoadPlist(at: url) as! [NSDictionary]
        self.sequences = rawSequences.map { UIBotSequence(from: $0) }
        
        commonInit()
    }
    
    init(sequences: [UIBotSequence], delegate: UIBotDelegate, dataSource: UIBotDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        self.sequences = sequences
        
        commonInit()
    }
    
    func commonInit() {
        self.sequenceIndex = 0
    }
    
    var allSequencesComplete: Bool {
        return sequenceIndex == sequences.count - 1 && allStepsComplete
    }
    
    var allStepsComplete: Bool {
        return pending == nil && sequence.isComplete
    }
    
    private var sequence: UIBotSequence! {
        didSet {
            sequence.reset()
            delegate.uiBot(self, loadedSequence: sequenceIndex, named: sequence.name)
            pending = try! sequence.step()
        }
    }
    
    private var sequences: [UIBotSequence]!
    
    private var sequenceIndex: Int! {
        didSet {
            assert(sequenceIndex < sequences.count)
            sequence = sequences[self.sequenceIndex]
        }
    }
    
    private var pending: UIBotOperation? {
        didSet {
            guard let pending = self.pending else {
                return
            }
            let isTest = dataSource.uiBot(self, operationIsTest: pending.name)
            delegate.uiBot(self, loadedOperation: pending.name, fromSection: pending.section, operationIndex: pending.index, isTest: isTest)
        }
    }
    
    private func executeOnConsecutiveRunLoopIterations(blocks: [() -> Void]) {
        var counter = 0
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { (observer, activity) in
            if activity.contains(.beforeWaiting) && counter < blocks.count {
                
                let block = blocks[counter]
                RunLoop.main.perform {
                    block()
                }
                counter += 1
            } else {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
            }
        }
        
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
    }
    
    var delegate: UIBotDelegate!
    
    var dataSource: UIBotDataSource!
    
    private func executeTest(named name: String, data: Any) -> () -> Void {
        return {
            let (pass, msg) = self.dataSource.uiBot(self, executeTestNamed: name, data: data)
            self.delegate.uiBot(self, evaluated: name, didPass: pass, details: msg)
        }
    }
    
    private func block(for operation: UIBotOperation) -> () -> Void {
        if dataSource.uiBot(self, operationIsTest: operation.name) {
            return executeTest(named: operation.name, data: operation.data)
        } else {
            return dataSource.uiBot(self, blockForOperationNamed: operation.name, operationData: operation.data)
        }
    }
    
    private func blocksDidExecute() {
        if sequence.isComplete {
            self.pending = nil
            delegate.uiBot(self, didCompleteSequence: sequenceIndex, named: sequence.name, isLast: allSequencesComplete)
        } else {
            self.pending = try! sequence.step()
        }
    }
    
    // MARK: Stepping
    
    private func checkForStepError() -> UIBotError? {
        if allSequencesComplete {
            return UIBotError.allSequencesComplete
        } else if allStepsComplete {
            return UIBotError.sequenceIsComplete
        } else {
            return nil
        }
    }
    
    var sequenceName: String {
        return sequence.name
    }
    
    private func executeOperation(_ operation: UIBotOperation) {
        let block = self.block(for: operation)
        block()
        blocksDidExecute()
    }
    
    private func executeOperations(_ operations: [UIBotOperation]) {
        
        var blocks = [() -> Void]()
        
        for (ii, operation) in operations.enumerated() {
            
            if ii != 0 {
                blocks.append {
                    let isTest = self.dataSource.uiBot(self, operationIsTest: operation.name)
                    self.delegate.uiBot(self, loadedOperation: operation.name, fromSection: operation.section, operationIndex: operation.index, isTest: isTest)
                }
            }
            
            let block = self.block(for: operation)
            blocks.append(block)
        }
        
        if sequence.isComplete {
            self.pending = nil
            blocks.append {
                self.delegate.uiBot(self, didCompleteSequence: self.sequenceIndex, named: self.sequence.name, isLast: self.allSequencesComplete)
            }
        } else {
            blocks.append { self.pending = try! self.sequence.step() }
        }
        
        executeOnConsecutiveRunLoopIterations(blocks: blocks)
    }
    
    func step() throws {
        if let error = checkForStepError() {
            throw error
        }
        guard let pending = self.pending else {
            fatalError("sequence not yet complete, but no pending block.")
        }
        executeOperation(pending)
        
    }
    
    func step(to location: SequenceLocation) throws {
        if let error = checkForStepError() {
            throw error
        }
        
        guard let pending = self.pending else {
            fatalError("sequence not yet complete, but no pending block.")
        }
        
        guard !sequence.isComplete else {
            executeOperation(pending)
            return
        }
        
        if sequence.atSectionStart && location == .nextSection {
            executeOperation(pending)
        } else {
            let remainingOps = try! sequence.step(to: location)
            executeOperations([pending] + remainingOps)
        }
    }

    func loadNextSequence() throws {
        guard sequenceIndex < sequences.count - 1 else {
            throw UIBotError.noSequencesRemaining
        }
        
        sequenceIndex += 1
    }
    
    func reset() {
        sequenceIndex = 0
    }
}


func ConvertSeparatedStringToArray(_ separatedString: String, separator: String = ",") -> [String] {
    var array: [String]
    if separatedString.contains(separator) {
        array = separatedString.components(separatedBy: separator)
        array = array.map({$0.trimmingCharacters(in: .whitespaces)})
    } else {
        array = [separatedString.trimmingCharacters(in: .whitespaces)]
    }
    return array
}
