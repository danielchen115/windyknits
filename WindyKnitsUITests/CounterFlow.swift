import XCTest

/// Seeded sample data → Counter tab → row count advances on tap. Exercises
/// the per-project `@AppStorage` plumbing end-to-end (the Counter tab lands
/// on the newest active project, which is `p1` after seeding).
final class CounterFlow: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_counterIncrementsRowsFromSeededState() {
        let app = UITestApp().launch("--ui-test-reset", "--ui-test-seed-samples")

        app.tab("Counter").tap()

        // The seeded `p1` (Marigold Cardigan) is the newest active project,
        // so CounterTabRoot lands on it. The nav-bar title is the cleanest
        // proof we resolved the right project.
        XCTAssertTrue(app.wait(for: app.text("Marigold Cardigan")),
                      "Counter tab should land on the newest active sample project")

        // The seeder writes rows=5 / stitches=34 into the App Group, but the
        // default active counter is `.stitches`, so the giant value is "34".
        // Switch to the rows counter — that's what we want to assert against.
        app.id("counter.secondary.rows").tap()

        let value = app.id("counter.primaryValue")
        XCTAssertTrue(app.wait(for: value))
        XCTAssertEqual(value.label, "5",
                       "Seeded counter snapshot should put p1 at row 5")

        // Tap the value text directly — the surrounding card has the
        // `onTapGesture` and the tap propagates up to it.
        value.tap()
        // Predicate-wait rather than equality so we don't race with the
        // SwiftUI re-render after AppStorage updates.
        let expectation = expectation(
            for: NSPredicate(format: "label == %@", "6"),
            evaluatedWith: value,
            handler: nil)
        wait(for: [expectation], timeout: 3)
    }
}
