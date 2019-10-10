//
//  BotSequence.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 24/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation

enum SequenceError: Error {
    case sequenceComplete
}

enum SequenceLocation {
    case nextSection
    case end
}

class UIBotSequence {
    var name: String
    /*
     An array consisting of Operation structs and (optionally) strings. Each operation encodes an 'action' that simulates user behaviour (e.g. 'tap-screen', 'tap-delete', etc), whereas string entries can be used to summarise the intent of an up-coming sequence of operations (e.g. 'Delete last added waypoint'). Strings can appear at any position in the array and in any quantity, but if present they must be followed by at least one operation.
     */
    private var operations: [Any]
    private var position: Int = 0
    var section: String?
    
    init(from rawSequence: NSDictionary) {
        self.name = rawSequence["name"] as! String
        self.operations = rawSequence["operations"] as! [Any]
    }
    
    init(from url: URL) {
        let rawSequence = LoadPlist(at: url) as! NSDictionary
        self.name = rawSequence["name"] as! String
        self.operations = rawSequence["operations"] as! [Any]
    }
    
    func step(to location: SequenceLocation) throws -> [UIBotOperation] {
        guard !isComplete else {
            throw SequenceError.sequenceComplete
        }
        
        if let name = operations[position] as? String {
            self.section = name
            position += 1
        }
        
        var outstanding = [UIBotOperation]()
        while !isComplete {
            if let dict = operations[position] as? NSDictionary {
                let operation = UIBotOperation(from: dict, index: position, section: self.section)
                outstanding.append(operation)
                position += 1
            } else if let section = operations[position] as? String {
                if location == .end {
                    self.section = section
                    position += 1
                } else {
                    break
                }
            }
        }
        
        return outstanding
    }
    
    func reset() {
        self.position = 0
    }
    
    /*
     Returns the next operation in the sequence.
     */
    func step() throws -> UIBotOperation {
        guard !isComplete else {
            throw SequenceError.sequenceComplete
        }
        
        
        if let name = operations[position] as? String {
            self.section = name
            position += 1
        }
        
        let rawOp = operations[position] as! NSDictionary
        let op = UIBotOperation(from: rawOp, index: position, section: self.section)
        position += 1
        return op
    }
    
    /*
     Returns true if the next step() call will return the first operation in a section.
     */
    var atSectionStart: Bool {
        return operations[position] is String
    }
    
    var isComplete: Bool {
        return position > operations.count - 1
    }
}
