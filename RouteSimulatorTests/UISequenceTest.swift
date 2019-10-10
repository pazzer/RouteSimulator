//
//  SequenceTest.swift
//  RouteSimulatorTests
//
//  Created by Paul Patterson on 25/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import XCTest

class UISequenceTest: XCTestCase {

    func testSequenceARandom() {
        var op: UIBotOperation
        var ops: [UIBotOperation]
        
        let sequenceA = SequenceA()
        XCTAssertTrue(sequenceA.atSectionStart)
        
        let _ = try! sequenceA.step() // Jumps over title, returns first op at seq[1], winds position on to [2]
        
        op = try! sequenceA.step()
        XCTAssertEqual(op.name, "1.1")
        
        //
        ops = try! sequenceA.step(to: .nextSection)
        XCTAssertEqual(ops.count, 1)
        XCTAssertTrue(sequenceA.atSectionStart)
        
        ops = try! sequenceA.step(to: .nextSection)
        op = ops.first!
        XCTAssertEqual(ops.count, 1)
        XCTAssertEqual(op.name, "2.0")
        XCTAssertEqual(op.section, "Section Two")
        XCTAssertTrue(sequenceA.atSectionStart) // at section three
        
        let _ = try! sequenceA.step() // 3.0
        let _ = try! sequenceA.step() // 3.1
        ops = try! sequenceA.step(to: .nextSection) // [3.2, 3.3]
        XCTAssertEqual(ops.count, 2)
        XCTAssertTrue(sequenceA.atSectionStart)
        
        ops = try! sequenceA.step(to: .end)
        XCTAssertEqual(ops.count, 1)
        XCTAssertTrue(sequenceA.isComplete)
        op = ops.first!
        XCTAssertEqual(op.section, "Section Four")
        XCTAssertEqual(op.name, "4.0")
        
        var thrownError: Error!
        XCTAssertThrowsError(try sequenceA.step(), "") { (error) in
            thrownError = error
        }
        XCTAssertTrue(thrownError is SequenceError)
    }
    
    func testSequenceAToEnd() {
        var op: UIBotOperation
        var ops: [UIBotOperation]
        
        let sequence = SequenceA()
        let _ = try! sequence.step()
        ops = try! sequence.step(to: .end)
        XCTAssertEqual(ops.count, 8)
        
        op = ops.first!
        XCTAssertEqual(op.name, "1.1")
        XCTAssertEqual(op.section, "Section One")
        op = ops.last!
        XCTAssertEqual(op.name, "4.0")
        XCTAssertEqual(op.section, "Section Four")
    }
    
    func testSequenceASections() {
        var ops: [UIBotOperation]
        let sequence = SequenceA()
        
        // at start of section 1
        ops = try! sequence.step(to: .nextSection)
        XCTAssertEqual(ops.count, 3)
        
        // at start section 2
        ops = try! sequence.step(to: .nextSection)
        XCTAssertEqual(ops.count, 1)
        
        // at start of section 3
        ops = try! sequence.step(to: .nextSection)
        XCTAssertEqual(ops.count, 4)
        
        // at start of section 4
        ops = try! sequence.step(to: .nextSection)
        XCTAssertEqual(ops.count, 1)
        
        var thrownError: Error!
        XCTAssertThrowsError(try sequence.step(), "") { (error) in
            thrownError = error
        }
        
        XCTAssertTrue(sequence.isComplete)
        XCTAssertTrue(thrownError is SequenceError)
    }
    
    func testSequenceAStepping() {
        var op: UIBotOperation
        let sequence = SequenceA()
        
        let _ = try! sequence.step()
        let _ = try! sequence.step()
        op = try! sequence.step()
        XCTAssertEqual(op.name, "1.2")
        op = try! sequence.step()
        XCTAssertEqual(op.name, "2.0")
        
    }
}
