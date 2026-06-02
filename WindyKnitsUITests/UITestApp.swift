import XCTest

/// Thin wrapper around `XCUIApplication` so tests can read like prose. Owns
/// one launched app per test; pass launch arguments through `launch(_:)` and
/// pluck elements out via `id(_:)` / `tab(_:)` / `text(_:)`.
struct UITestApp {
    let app: XCUIApplication

    init() { self.app = XCUIApplication() }

    /// Launch the app with the given launch arguments. Returns self so calls
    /// can chain: `UITestApp().launch("--ui-test-reset")`.
    ///
    /// `--ui-test-skip-signin` is injected automatically so tests skip the
    /// Sign in with Apple welcome screen and land at the tab bar. Tests
    /// that specifically need to exercise SIWA should use
    /// `launchAtWelcome(...)` instead.
    @discardableResult
    func launch(_ arguments: String...) -> Self {
        app.launchArguments = arguments + ["--ui-test-skip-signin"]
        app.launch()
        return self
    }

    /// Launch the app without the SIWA bypass, so the welcome screen is
    /// the first thing rendered. Use this only for welcome-screen tests.
    @discardableResult
    func launchAtWelcome(_ arguments: String...) -> Self {
        app.launchArguments = arguments
        app.launch()
        return self
    }

    /// Tap target for the tab bar buttons by visible label ("Today",
    /// "Projects", "Counter", "You").
    func tab(_ label: String) -> XCUIElement {
        app.tabBars.buttons[label]
    }

    /// Find the first descendant carrying the given accessibility identifier.
    /// `matching(identifier:)` searches the whole tree, so tests don't have
    /// to care which element type SwiftUI synthesised under the hood.
    func id(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Convenience for finding visible text — handy for assertions like
    /// "the project's title appears on the detail screen".
    func text(_ label: String) -> XCUIElement {
        app.staticTexts[label]
    }

    /// Waits for the element to appear; returns whether it did. Default 3s
    /// timeout matches Xcode's animation default and the longest standard
    /// navigation push.
    @discardableResult
    func wait(for element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        element.waitForExistence(timeout: timeout)
    }
}
