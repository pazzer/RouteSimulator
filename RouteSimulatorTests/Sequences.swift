//
//  Sequences.swift
//  RouteSimulatorTests
//
//  Created by Paul Patterson on 25/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
@testable import RouteSimulator

func MakeRawOperation(named name: String, data: Any) -> NSDictionary {
    return ["name": name, "data": data]
}

func SequenceA() -> UIBotSequence {
    let ops: [Any] = [
        "Section One",
        MakeRawOperation(named: "1.0", data: "+,4"),
        MakeRawOperation(named: "1.1", data: "-,6"),
        MakeRawOperation(named: "1.2", data: "+,1"),
        "Section Two",
        MakeRawOperation(named: "2.0", data: "-,15"),
        "Section Three",
        MakeRawOperation(named: "3.0", data: "*,3"),
        MakeRawOperation(named: "3.1", data: "+,10"),
        MakeRawOperation(named: "3.2", data: "+,2"),
        MakeRawOperation(named: "3.3", data: "-,56"),
        "Section Four",
        MakeRawOperation(named: "4.0", data: "*,3")
    ]
    return UIBotSequence(from: ["name": "A", "operations":ops])
}

func SequenceB() -> UIBotSequence {
    let ops: [Any] = [
        "Section One",
        MakeRawOperation(named: "1.0", data: "+,1"),
        "Section Two",
        MakeRawOperation(named: "2.0", data: "+,4"),
        "Section Three",
        MakeRawOperation(named: "3.0", data: "+,8"),
        MakeRawOperation(named: "3.1", data: "+,16"),
        MakeRawOperation(named: "3.2", data: "+,32"),
        "Section Four",
        MakeRawOperation(named: "4.0", data: "+,64")
    ]
    return UIBotSequence(from: ["name": "B", "operations":ops])
}

func SequenceC() -> UIBotSequence {
    let ops: [Any] = [
    "Section One",
    MakeRawOperation(named: "1.0", data: "+,3"),
    "Section Two",
    MakeRawOperation(named: "2.0", data: "+,3"),
    "Section Three",
    MakeRawOperation(named: "3.0", data: "+,3"),
    ]
    return UIBotSequence(from: ["name": "C", "operations":ops])
}



