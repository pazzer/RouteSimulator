//
//  BotTest.swift
//  RouteSimulatorTests
//
//  Created by Paul Patterson on 25/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import XCTest

class UIBotTest: XCTestCase, UIBotDelegate, UIBotDataSource {
    
    var result = Double(0)
    
    // MARK: UIBotDataSource
    
    func uiBot(_ uiBot: UIBot, operationIsTest operationName: String) -> Bool {
        return false
    }
    
    func uiBot(_ uiBot: UIBot, blockForOperationNamed operationName: String, operationData: Any) -> (() -> Void) {
        
        return {
            let `string` = operationData as! String
            let comps = `string`.components(separatedBy: ",")
            let operation = comps.first!
            let value = Double(comps.last!)!
            switch operation {
            case "+":
                self.result += value
            case "-":
                self.result -= value
            case "*":
                self.result *= value
            case "/":
                self.result /= value
            default:
                fatalError("\(operation) not recognised")
            }
        }
    }
    
    func uiBot(_ uiBot: UIBot, executeTestNamed testName: String, data: Any?) -> (pass: Bool, msg: String) {
        return (true, "")
    }

    func uiBot(_ uiBot: UIBot, loadedOperation named: String, fromSection section: String?, operationIndex: Int, isTest: Bool) {
        lastLoadedOperation = named
        guard let block = loadedOpBlock else {
            return
        }
        
        block()
    }
    
    
    func uiBot(_ uiBot: UIBot, didCompleteSequence index: Int, named name: String?, isLast: Bool) {
        guard let block = sequenceCompleteBlock else {
            return
        }
        
        block()
    }
    
    var lastLoadedOperation: String?
    var loadedOpBlock: (() -> Void)?
    var sequenceCompleteBlock: (() -> Void)?
    
    func testSteppingThroughSections() {
        
        // Test 1

        var bot = UIBot(sequences: [SequenceB()])
        bot.delegate = self
        bot.dataSource = self
        self.result = 0

        try! bot.step() // executed 1.0, now at 2.0
        try! bot.step() // executed 2.0, now at 3.0

        var resultExpectation = XCTestExpectation(description: "Result == 125")

        sequenceCompleteBlock = {
            if self.result == 125 {
                resultExpectation.fulfill()
            }
        }


        try! bot.step(to: .end) // executed 3.0, .1, .2 and 4.0, now at end
        wait(for: [resultExpectation], timeout: 10)

        sequenceCompleteBlock = nil
        
        // Test 2
        bot = UIBot(sequences: [SequenceB()])
        bot.delegate = self
        bot.dataSource = self
        self.result = 0

        try! bot.step() // executed 1.0, now at 2.0
        XCTAssertEqual(result, 1)

        resultExpectation = XCTestExpectation(description: "Result == 5")

        loadedOpBlock = {
            if self.result == 5 {
                resultExpectation.fulfill()
            }
        }

        try! bot.step(to: .nextSection) // executed 2.0, now at 3.0
        wait(for: [resultExpectation], timeout: 10)
        XCTAssertEqual(lastLoadedOperation!, "3.0")
        loadedOpBlock = nil
    }
    
    func testSequenceLoading() {
        // Test 1
        var bot = UIBot(sequences: [SequenceB()])
        bot.delegate = self
        bot.dataSource = self
        result = 0
        try! bot.step()
        try! bot.step()
        
        var thrownError: UIBotError?
        XCTAssertThrowsError(try bot.loadNextSequence(), "") { (error) in
            thrownError = error as? UIBotError
        }
        XCTAssertTrue(thrownError == UIBotError.noSequencesRemaining)
        
        // Test 2
        
        
        bot = UIBot(sequences: [SequenceA(), SequenceB(), SequenceC()])
        bot.delegate = self
        bot.dataSource = self
        self.result = 0
        try! bot.loadNextSequence()
        XCTAssertEqual(bot.sequenceName, "B")
        
        try! bot.loadNextSequence()
        XCTAssertEqual(bot.sequenceName, "C")
        
        XCTAssertThrowsError(try bot.loadNextSequence(), "") { (error) in
            thrownError = error as? UIBotError
        }
        XCTAssertTrue(thrownError == UIBotError.noSequencesRemaining)
        XCTAssertEqual(self.result, 0)
    }
    
    func testResetting() {
        let bot = UIBot(sequences: [SequenceA(), SequenceB(), SequenceC()])
        bot.delegate = self
        bot.dataSource = self
        result = 0
        
        try! bot.loadNextSequence()
        try! bot.loadNextSequence()
        XCTAssertEqual(bot.sequenceName, "C")
        try! bot.step() // executed 1.0 (c)
        try! bot.step() // executed 2.0 (c)
        
        XCTAssertEqual(self.result, 6)
        
        bot.reset()
        result = 0
        XCTAssertEqual(bot.sequenceName, "A")
        
        
        let resultExpectation = XCTestExpectation(description: "Result == -1")
        let nameExpectation = XCTestExpectation(description: "lastLoadedOperation == 2.0")
        loadedOpBlock = {
            if self.result == -1 {
                resultExpectation.fulfill()
            }
            if let opName = self.lastLoadedOperation, opName == "2.0" {
                nameExpectation.fulfill()
            }
        }
        
        try! bot.step(to: .nextSection) // executing 1.0, .1, .2, now at 2.0
        wait(for: [resultExpectation, nameExpectation], timeout: 10)
        XCTAssertEqual(lastLoadedOperation!, "2.0")
    }
    
    func testRandomlyStepThroughAllSequences() {
        let seqs = [SequenceA(),SequenceB(),SequenceC()]
        let bot = UIBot(sequences: seqs)
        bot.delegate = self
        bot.dataSource = self
        
        // Sequence A /////
        
        try! bot.step() // executed 1.0, now at 1.1
        try! bot.step() // executed 1.1, now at 1.2

        XCTAssertEqual(result, -2)
        
        try! bot.step(to: .nextSection) // executed 1.2, now at 2.0
        
        XCTAssertEqual(result, -1)
        
        try! bot.step(to: .nextSection) // executed, 2.0, now at 3.0
        
        XCTAssertEqual(result, -16)
        
        let expectation = XCTestExpectation(description: "Result == -92")
        loadedOpBlock = {
            if self.result == -92 {
                expectation.fulfill()
            }
        }
        
        try! bot.step(to: .nextSection) // executed 3.0, .1, .2 and .3, now at 4.0
        wait(for: [expectation], timeout: 10)
        loadedOpBlock = nil
        
        try! bot.step() // Executed 4.0, now finished Sequence A
        
        XCTAssertEqual(result, -276)
        XCTAssertTrue(bot.allStepsComplete)
        
        var thrownError: UIBotError?
        XCTAssertThrowsError(try bot.step(), "", { (error) in
            thrownError = error as? UIBotError
        })
        XCTAssertEqual(thrownError, UIBotError.sequenceIsComplete)
        
        
        
        try! bot.loadNextSequence()
        self.result = 0
        
        // Sequence B ////
        
        try! bot.step() // executed 1.0, now at 2.0
        
        XCTAssertNotNil(lastLoadedOperation)
        XCTAssertEqual(lastLoadedOperation!, "2.0")
        XCTAssertEqual(result, 1)
        
        try! bot.step(to: .nextSection) // executed 2.0, now at 3.0
        XCTAssertNotNil(lastLoadedOperation)
        XCTAssertEqual(lastLoadedOperation!, "3.0")
        XCTAssertEqual(result, 5)
        
        
        var resultExpectation = XCTestExpectation(description: "Result == 61")
        var opNameExpectation = XCTestExpectation(description: "OpName == 4.0")
        loadedOpBlock = {
            if self.result == 61 {
                resultExpectation.fulfill()
            }
            if let opName = self.lastLoadedOperation, opName == "4.0" {
                opNameExpectation.fulfill()
            }
        }
        try! bot.step(to: .nextSection) // executed 3.0, .1 and .2, now at 4.0
        wait(for: [resultExpectation, opNameExpectation], timeout: 10)
        loadedOpBlock = nil
        
        try! bot.step(to: .end) // executed 4.0, now finished Sequence B
        
        XCTAssertEqual(result, 125)
        XCTAssertTrue(bot.allStepsComplete)
        
        try! bot.loadNextSequence()
        self.result = 0
        
        // Sequence C /////
        
        resultExpectation = XCTestExpectation(description: "Result == 9")
        opNameExpectation = XCTestExpectation(description: "OpName == 3.0")
        sequenceCompleteBlock = {
            if self.result == 9 {
                resultExpectation.fulfill()
            }
            if let opName = self.lastLoadedOperation, opName == "3.0" {
                opNameExpectation.fulfill()
            }
        }
        
        
        try! bot.step(to: .end) // executed 1.0, 2.0 and 3.0, now at end
        wait(for: [resultExpectation, opNameExpectation], timeout: 10)
        sequenceCompleteBlock = nil
        
        
        XCTAssertThrowsError(try bot.loadNextSequence(), "") { (error) in
            thrownError = error as? UIBotError
        }
        XCTAssertEqual(thrownError!, UIBotError.noSequencesRemaining)
    }
    
    
    
    func testSequenceCompleteDelegate() {
        // Tests whether bot.allSequncesComplete returns the correct value in the delegate method <didCompleteSequence>
        let seqs = [SequenceA(),SequenceB(),SequenceC()]
        let bot = UIBot(sequences: seqs)
        bot.delegate = self
        bot.dataSource = self
        
        try! bot.loadNextSequence()
        try! bot.loadNextSequence()
        
        let allCompleteExpectation = XCTestExpectation(description: "All Complete")
        sequenceCompleteBlock = {
            if bot.allSequencesComplete == true {
                allCompleteExpectation.fulfill()
            }
        }
        try! bot.step(to: .end)
        wait(for: [allCompleteExpectation], timeout: 10)
        
        
        
    }
}
