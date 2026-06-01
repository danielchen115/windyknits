import Testing
import SwiftUI
@testable import WindyKnits

@MainActor
@Suite("NavCoordinator")
struct NavCoordinatorTests {

    @Test func startsWithEmptyPath() {
        let nav = NavCoordinator()
        #expect(nav.path.isEmpty)
        #expect(nav.path.count == 0)
    }

    @Test func pushAddsRouteToPath() {
        let nav = NavCoordinator()
        nav.push(.project("p1"))
        #expect(nav.path.count == 1)
        nav.push(.counter("p1"))
        #expect(nav.path.count == 2)
    }

    @Test func resetToReplacesEntireStackWithSingleRoute() {
        let nav = NavCoordinator()
        nav.push(.importPDF)
        nav.push(.manualPattern)
        #expect(nav.path.count == 2)
        nav.resetTo(.project("p1"))
        #expect(nav.path.count == 1)
    }
}

@MainActor
@Suite("Route")
struct RouteTests {

    @Test func sameCaseAndPayloadAreEqual() {
        #expect(Route.project("p1") == Route.project("p1"))
        #expect(Route.counter("p1") == Route.counter("p1"))
        #expect(Route.importPDF == Route.importPDF)
    }

    @Test func differentPayloadsAreNotEqual() {
        #expect(Route.project("p1") != Route.project("p2"))
    }

    @Test func differentCasesAreNotEqual() {
        #expect(Route.project("p1") != Route.counter("p1"))
        #expect(Route.importPDF != Route.manualPattern)
    }
}
