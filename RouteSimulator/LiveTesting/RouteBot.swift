//
//  RouteBot.swift
//  RouteSimulator
//
//  Created by Paul Patterson on 12/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import Foundation

enum RouteBotOperation: String {
    
    case setCrosshairsOnPoint = "SET_CROSSHAIRS_ON_POINT"
    case setCrosshairsOnNode = "SET_CROSSHAIRS_ON_NODE"
    case setCrosshairsOnArrow = "SET_CROSSHAIRS_ON_POLYLINE"
    case setCrosshairsInZone = "SET_CROSSHAIRS_IN_ZONE"
    
    case addWaypoints = "ADD_NODES"
    case addRandomNode = "ADD_RANDOM_NODE"
    case addNodesToZones = "ADD_NODES_TO_ZONES"
    
    case deleteNode = "DELETE_NODE"
    case deleteArrow = "DELETE_POLYLINE"
    
    case merge = "MERGE"
    
    case selectNode = "SELECT_WAYPOINT"
    case setNext = "SET_NEXT"
    
    case tapCrosshairs = "TAP_SELECT"
    case tapAdd = "TAP_ADD"
    case tapRemove = "TAP_REMOVE"
    
    case evaluate = "EVALUATE"
    case suspend = "SUSPEND"
}
