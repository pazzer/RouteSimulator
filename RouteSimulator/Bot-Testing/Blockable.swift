//
//  Blockable.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 13/03/2020.
//  Copyright © 2020 Paul Patterson. All rights reserved.
//

import Foundation

protocol Blockable {
    var block: () -> Void { get set }
}

struct BlockWithDelay: Blockable {
    var block: () -> Void
    let delay: TimeInterval
}

struct SimpleBlock: Blockable {
    var block: () -> Void
}
