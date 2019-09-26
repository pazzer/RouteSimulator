//
//  BotOperation.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 24/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation
import UIKit

struct UIBotOperation {
    
    let name: String
    let data: Any
    
    let section: String
    let index: Int
    
    init(from rawOperation: NSDictionary, index: Int, section: String) {
        self.name = rawOperation["name"] as! String
        self.data = rawOperation["data"] as Any
        self.section = section
        self.index = index
    }
}
