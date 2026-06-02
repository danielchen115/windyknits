import XCTest

/// Proves the PDF-import feature flag actually changes the visible UI in
/// both directions. If this fails, the launch-argument plumbing or the
/// flag's effect on the start CTA has regressed.
final class PdfImportFeatureFlag: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_importPDFAbsentWhenFlagDisabled() {
        let app = UITestApp().launch("--ui-test-reset", "--ui-test-pdf-import-off")

        let addPattern = app.id("today.start.addPattern")
        XCTAssertTrue(app.wait(for: addPattern),
                      "Single-button start CTA should appear when import is off")
        XCTAssertFalse(app.id("today.start.importPDF").exists,
                       "Import PDF button must not be present when the flag is off")
    }

    @MainActor
    func test_importPDFPresentWhenFlagEnabled() {
        let app = UITestApp().launch("--ui-test-reset", "--ui-test-pdf-import-on")

        XCTAssertTrue(app.wait(for: app.id("today.start.importPDF")),
                      "Import PDF button should appear when the flag is on")
        // The two-button row also keeps the manual entry point, sharing the
        // same id as the single-button case.
        XCTAssertTrue(app.id("today.start.addPattern").exists,
                      "Manual entry button is present in either flag state")
    }
}
