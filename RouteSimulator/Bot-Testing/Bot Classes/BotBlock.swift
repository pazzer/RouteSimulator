//
//  BotBlock.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 01/04/2020.
//  Copyright © 2020 Paul Patterson. All rights reserved.
//

import Foundation

struct BotBlock {
    var block: () -> Void
    var delay: TimeInterval?
    
    init(block: @escaping () -> Void) {
        self.block = block
    }
    
    init(block: @escaping () -> Void, delay: TimeInterval) {
        self.block = block
        self.delay = delay
    }
}
