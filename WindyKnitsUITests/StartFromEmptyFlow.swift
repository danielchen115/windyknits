import XCTest

/// Empty install → user creates their first pattern manually → it appears as
/// the active project. Covers the happy-path onboarding flow that real users
/// hit on first launch.
final class StartFromEmptyFlow: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_emptyToManualPatternToLibrary() {
        // Wipe + PDF off so the start CTA collapses to a single "Add pattern"
        // button with id `today.start.addPattern`.
        let app = UITestApp().launch("--ui-test-reset", "--ui-test-pdf-import-off")

        let addPattern = app.id("today.start.addPattern")
        XCTAssertTrue(app.wait(for: addPattern), "Empty-state CTA should appear on Today")
        addPattern.tap()

        // ManualStart screen — fill in the required name and continue.
        let name = app.id("manualPattern.nameField")
        XCTAssertTrue(app.wait(for: name))
        name.tap()
        name.typeText("Test Cowl")

        app.id("manualPattern.continueButton").tap()

        // ManualBuild screen — draft one row, commit, then save.
        let rowInput = app.id("manualPattern.rowInput")
        XCTAssertTrue(app.wait(for: rowInput))
        rowInput.tap()
        rowInput.typeText("Cast on 96")
        app.id("manualPattern.rowSend").tap()
        app.id("manualPattern.saveButton").tap()

        // Saved confirmation → open project.
        let openProject = app.id("manualPattern.openProject")
        XCTAssertTrue(app.wait(for: openProject))
        openProject.tap()

        // Project detail screen now renders the new project's title.
        XCTAssertTrue(app.wait(for: app.text("Test Cowl")),
                      "New project's detail screen should show its title")
    }
}
