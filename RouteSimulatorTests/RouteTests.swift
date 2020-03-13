//
//  RouteSimulatorTests.swift
//  RouteSimulatorTests
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import XCTest
@testable import RouteSimulator

class RouteTests: XCTestCase {

    var routeA: Route {
        let route = Route()
        ["a", "b", "c", "d"].forEach { route.add(waypointNamed: $0, at: .zero) }
        route.setNext(ofWaypointNamed: "a", toWaypointNamed: "b")
        route.setNext(ofWaypointNamed: "b", toWaypointNamed: "c")
        return route
    }
    
    var routeB: Route {
        let route = Route()
        ["a", "b", "c", "d", "e", "f"].forEach({route.add(waypointNamed: $0, at: .zero)})
        route.setNext(ofWaypointNamed: "a", toWaypointNamed: "b")
        route.setNext(ofWaypointNamed: "b", toWaypointNamed: "c")
        route.setNext(ofWaypointNamed: "c", toWaypointNamed: "d")
        route.setNext(ofWaypointNamed: "d", toWaypointNamed: "e")
        route.setNext(ofWaypointNamed: "e", toWaypointNamed: "f")
        route.setNext(ofWaypointNamed: "f", toWaypointNamed: "a")
        return route
        
    }
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func deadEnds(in route: Route) -> [String] {
        return route.waypointNames.filter { (name) -> Bool in
            return route.nameOfWaypointFollowing(waypointNamed: name) == nil
        }
    }
    
    func next(of names: [String], from route: Route) -> [String?] {
        return names.sorted().map({route.nameOfWaypointFollowing(waypointNamed: $0)})
    }
    
    func testA() {
        let routeA = self.routeA
        
        XCTAssertEqual(routeA.nameOfWaypointPreceeding(waypointNamed: "c"), "b")
        routeA.setNext(ofWaypointNamed: "b", toWaypointNamed: "d")
        XCTAssertEqual(routeA.nameOfWaypointPreceeding(waypointNamed: "c"), nil)
        XCTAssertEqual(routeA.nameOfWaypointPreceeding(waypointNamed: "d"), "b")
        
        XCTAssertFalse(routeA.circularRelationshipExistsBetween(waypointNamed: "c", and: "d"))
        routeA.setNext(ofWaypointNamed: "c", toWaypointNamed: "d")
        routeA.setNext(ofWaypointNamed: "d", toWaypointNamed: "c")
        XCTAssertTrue(routeA.circularRelationshipExistsBetween(waypointNamed: "c", and: "d"))

        routeA.setNext(ofWaypointNamed: "b", toWaypointNamed: "c")

        XCTAssertEqual(deadEnds(in: routeA).count, 1)
        routeA.setNext(ofWaypointNamed: "d", toWaypointNamed: "a")
        XCTAssertEqual(deadEnds(in: routeA).count, 0)
        
        XCTAssertFalse(routeA.circularRelationshipExistsBetween(waypointNamed: "d", and: "a"))
    }
    
    func testB() {
        let routeB = self.routeB
        XCTAssertEqual(deadEnds(in: routeB).count, 0)
        routeB.remove(waypointNamed: "c")
        XCTAssertEqual(routeB.waypointNames.count, 5)
        XCTAssertEqual(deadEnds(in: routeB), ["b"])

        routeB.setNext(ofWaypointNamed: "e", toWaypointNamed: "b")
        XCTAssertEqual(next(of: ["d", "e", "f"], from: routeB), ["e", "b", "a"])
        XCTAssertEqual(next(of: ["a", "b"], from: routeB), [nil, nil])


        routeB.remove(waypointNamed: "e")
        XCTAssertEqual(deadEnds(in: routeB), ["a", "b", "d"])

        routeB.remove(waypointNamed: "a")
        XCTAssertEqual(deadEnds(in: routeB), ["b", "d", "f"])

        routeB.add(waypointNamed: "g", at: .zero)
        routeB.setNext(ofWaypointNamed: "g", toWaypointNamed: "b")
        XCTAssertEqual(routeB.nameOfWaypointPreceeding(waypointNamed: "b"), "g")
    }
}
