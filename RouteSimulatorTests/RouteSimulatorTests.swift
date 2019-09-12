//
//  RouteSimulatorTests.swift
//  RouteSimulatorTests
//
//  Created by Paul Patterson on 11/09/2019.
//  Copyright © 2019 Paul Patterson. All rights reserved.
//

import XCTest


class RouteSimulatorTests: XCTestCase {

    var routeA: Route {
        let route = Route()
        ["a", "b", "c", "d"].forEach({route.add($0)})
        route.setNext(of: "a", to: "b")
        route.setNext(of: "b", to: "c")
        return route
    }
    
    var routeB: Route {
        let route = Route()
        ["a", "b", "c", "d", "e", "f"].forEach({route.add($0)})
        route.setNext(of: "a", to: "b")
        route.setNext(of: "b", to: "c")
        route.setNext(of: "c", to: "d")
        route.setNext(of: "d", to: "e")
        route.setNext(of: "e", to: "f")
        route.setNext(of: "f", to: "a")
        return route
        
    }
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func numberOfDeadEnds(in route: Route) -> Int {
        return route.locations.map({route.next(of: $0)}).filter({$0 == nil}).count
    }
    
    func deadEnds(in route: Route) -> [String] {
        return route.locations.sorted().filter { route.next(of: $0) == nil }
    }
    
    func next(of locations: [String], from route: Route) -> [String?] {
        return locations.sorted().map { route.next(of: $0) }
    }
    
    func testA() {
        let routeA = self.routeA
        XCTAssertEqual(routeA.previous(of: "c"), "b")
        routeA.setNext(of: "b", to: "d")
        XCTAssertEqual(routeA.previous(of: "c"), nil)
        XCTAssertEqual(routeA.previous(of: "d"), "b")
        
        
        XCTAssertFalse(routeA.circularRelationshipExistsBetween("c", and: "d"))
        routeA.setNext(of: "c", to: "d")
        routeA.setNext(of: "d", to: "c")
        XCTAssertTrue(routeA.circularRelationshipExistsBetween("c", and: "d"))
        
        routeA.setNext(of: "b", to: "c")
        
        
        XCTAssertEqual(numberOfDeadEnds(in: routeA), 1)
        routeA.setNext(of: "d", to: "a")
        XCTAssertEqual(numberOfDeadEnds(in: routeA), 0)
        XCTAssertFalse(routeA.circularRelationshipExistsBetween("d", and: "a"))
    }
    
    func testB() {
        let routeB = self.routeB
        XCTAssertEqual(numberOfDeadEnds(in: routeB), 0)
        routeB.remove("c")
        XCTAssertEqual(routeB.locations.count, 5)
        XCTAssertEqual(deadEnds(in: routeB), ["b"])
        
        routeB.setNext(of: "e", to: "b")
        XCTAssertEqual(next(of: ["d","e","f"], from: routeB), ["e", "b", "a"])
        XCTAssertEqual(next(of: ["a", "b"], from: routeB), [nil, nil])
        
        routeB.remove("e")
        XCTAssertEqual(deadEnds(in: routeB), ["a", "b", "d"])
        
        routeB.remove("a")
        XCTAssertEqual(deadEnds(in: routeB), ["b", "d", "f"])
        
        routeB.add("g")
        routeB.setNext(of: "g", to: "b")
        XCTAssertEqual(routeB.previous(of: "b"), "g")
    }
}
