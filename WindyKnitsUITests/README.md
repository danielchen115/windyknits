# WindyKnitsUITests

XCUITest target that drives the real app in the simulator. Pairs with the
`#if DEBUG` `LaunchArguments` parser in the main target so each test starts
from a known state.

## Launch arguments

All defined in `WindyKnits/LaunchArguments.swift`. Pass via
`XCUIApplication.launchArguments` (or `UITestApp.launch(...)`).

| Argument | Effect |
|---|---|
| `--ui-test-reset` | Wipes PatternStore + every `counter.*` key in the App Group (keychain preserved). Runs before any seeding. |
| `--ui-test-seed-samples` | Inserts `SampleData.projects` as real imported entries; seeds the curated counter snapshot for p1 (rows=5, stitches=34). |
| `--ui-test-pdf-import-off` | Forces `FeatureFlags.pdfImportEnabled = false`. |
| `--ui-test-pdf-import-on` | Forces `FeatureFlags.pdfImportEnabled = true`. |
| `--ui-test-skip-signin` | Injects a stub Sign in with Apple identity (`Test User`) so the welcome screen is skipped and the tab bar renders. **Added automatically by `UITestApp.launch(...)`** — only the SIWA-specific tests should use `launchAtWelcome(...)` to skip the injection. |

Combine freely: `--ui-test-reset --ui-test-seed-samples --ui-test-pdf-import-off`.

## Accessibility identifier convention

Pattern: `<screen>.<element>`, lowerCamelCase segments. Identifiers are added
in the SwiftUI views in the main target. The full list lives next to each
`accessibilityIdentifier(...)` call (search `accessibilityIdentifier` to
audit). Current set:

- `today.start.addPattern` — the manual-entry button on the empty-state CTA
  (used by both the single-button and two-button layouts).
- `today.start.importPDF` — the "Import PDF" button (only present when the
  flag is on).
- `library.add` — the `+` button in the Library tab header.
- `library.row.<projectId>` — each project row in the Library list.
- `counter.primaryCard` — the giant tap target on the counter.
- `counter.primaryValue` — the current value displayed at the top of the
  primary card.
- `counter.secondary.{rows,stitches,repeats}` — the secondary cards that
  switch which counter is active.
- `manualPattern.nameField` — the required title field on the start step.
- `manualPattern.continueButton` — "Start adding instructions".
- `manualPattern.saveButton` — "Done" in the nav bar of the build step.
- `manualPattern.rowInput` — the smart-bar text editor.
- `manualPattern.rowSend` — the `+` button that commits a drafted row.
- `manualPattern.openProject` — "Open project" on the saved confirmation.

## Running

From Xcode: ⌘U with the `WindyKnits` scheme (runs both unit tests and these
UI tests).

From the command line:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test \
  -project WindyKnits.xcodeproj \
  -scheme WindyKnits \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:WindyKnitsUITests
```

## Debugging a flaky test

1. In Xcode, open the latest report (⌘9 → Tests).
2. Expand the failing test to see each action; click the disclosure arrow on
   the failure to see the screenshot immediately before it.
3. Common causes: animation timing (use `waitForExistence`/`expectation(for:)`
   instead of `exists`), wrong tab (the `CounterTabRoot` lands on the newest
   active project, not always `p1`), or a missing accessibility identifier
   (add one and update this README).

## Adding a new test

1. Drop a new `XCTestCase` file into this folder; the filesystem-synced
   group picks it up automatically.
2. Use `UITestApp` for launching and finding elements. Mark the test method
   `@MainActor` (XCUI APIs are main-actor-bound).
3. If you need a new accessibility identifier, add it to both the SwiftUI
   view (with a `// UI tests look for this id` comment) and the list above.
4. If you need a new launch argument, extend `LaunchArguments.swift` and
   document it in the table above.
