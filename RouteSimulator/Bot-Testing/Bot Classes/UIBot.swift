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
    case midExecution
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
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?)
    
    func uiBotExecutingBlocks(_ uiBot: UIBot)
    func uiBotFinishedExecutingBlocks(_ uiBot: UIBot)
}

// TODO: Add simple logging statements
extension UIBotDelegate {
    func uiBot(_ uiBot: UIBot, loadedSequence index: Int, named name: String?) { }
    func uiBot(_ uiBot: UIBot, loadedOperation named: String, fromSection section: String?, operationIndex: Int, isTest: Bool) { }
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?, isLast: Bool) { }
    func uiBot(_ uiBot: UIBot, evaluated operation: String, didPass: Bool, details: String?) { }
    
    func uiBotExecutingBlocks(_ uiBot: UIBot) { }
    func uiBotFinishedExecutingBlocks(_ uiBot: UIBot) { }
}

extension Notification.Name {
    static let UIBotDidLoadSequence = Notification.Name("uibotDidLoadSequence")
}

class UIBot {
    
    func set(sequences: [UIBotSequence]) {
        self.sequences = sequences
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
    
    func restart() {
        assert(sequences.count > 0)
        assert(dataSource != nil)
        
        sequenceIndex = 0
    }
    
    private var sequences: [UIBotSequence]! {
        didSet {
            sequenceIndex = 0
        }
        
    }
    
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
    
    private func executeOnConsecutiveRunLoopIterations(blocks: [BotBlock]) {
        var counter = 0
        var delayed = false
        currentlyExecutingBlocks = true
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { (observer, activity) in
            if activity.contains(.beforeWaiting) && counter < blocks.count {
                if !delayed {
                    let botBlock = blocks[counter]
                    RunLoop.main.perform {
                        botBlock.block()
                    }
                    if let delay = botBlock.delay {
                        delayed = true
                        RunLoop.main.add(Timer(timeInterval: delay, repeats: false, block: { (_) in
                            delayed = false
                            counter += 1
                            if counter == blocks.count {
                                self.currentlyExecutingBlocks = false
                            }
                        }), forMode: RunLoop.Mode.common)
                    } else {
                        counter += 1
                        if counter == blocks.count {
                            self.currentlyExecutingBlocks = false
                        }
                    }
                }
                
            } else {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
            }
        }
        
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }
    
    var delegate: UIBotDelegate!
    
    var dataSource: UIBotDataSource!
    
    private func executeTest(named name: String, data: Any) -> BotBlock {
        return BotBlock {
            let (pass, msg) = self.dataSource.uiBot(self, executeTestNamed: name, data: data)
            self.delegate.uiBot(self, evaluated: name, didPass: pass, details: msg)
        }
    }
    
    private func botBlock(for operation: UIBotOperation) -> BotBlock {
        if dataSource.uiBot(self, operationIsTest: operation.name) {
            return executeTest(named: operation.name, data: operation.data)
        } else {
            let block = dataSource.uiBot(self, blockForOperationNamed: operation.name, operationData: operation.data)
            if let delay = operation.delay {
                return BotBlock(block: block, delay: delay)
            } else {
                return BotBlock(block: block)
            }
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
        if currentlyExecutingBlocks {
            return UIBotError.midExecution
        } else if allSequencesComplete {
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
        let botBlock = self.botBlock(for: operation)
        botBlock.block()
        blocksDidExecute()
        if let delay = botBlock.delay {
            currentlyExecutingBlocks = true
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { (_) in
                self.currentlyExecutingBlocks = false
            }
        }
    }
    
    private func executeOperations(_ operations: [UIBotOperation]) {
        
        var blocks = [BotBlock]()
        
        for (ii, operation) in operations.enumerated() {
            
            if ii != 0 {
                blocks.append(BotBlock {
                    let isTest = self.dataSource.uiBot(self, operationIsTest: operation.name)
                    self.delegate.uiBot(self, loadedOperation: operation.name, fromSection: operation.section, operationIndex: operation.index, isTest: isTest)
                })
            }
            
            let block = self.botBlock(for: operation)
            blocks.append(block)
        }
        
        if sequence.isComplete {
            self.pending = nil
            blocks.append(BotBlock {
                self.delegate.uiBot(self, didCompleteSequence: self.sequenceIndex, named: self.sequence.name, isLast: self.allSequencesComplete)
                })
            
        } else {
            blocks.append(BotBlock {
                self.pending = try! self.sequence.step()
            })
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
    
    private var currentlyExecutingBlocks = false {
        didSet {
            if self.currentlyExecutingBlocks {
                delegate.uiBotExecutingBlocks(self)
            } else {
                delegate.uiBotFinishedExecutingBlocks(self)
            }
        }
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
}
