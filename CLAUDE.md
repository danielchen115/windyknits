# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

WindyKnits is a SwiftUI iOS app for knitters — project library, PDF pattern import, row counter, and a Lock Screen Live Activity for hands-free row tracking. Single Xcode project, three targets, iOS 26.5+, Swift 5.0, universal (iPhone + iPad). Bundle ID `dc.WindyKnits`.

## Targets and layout

| Folder | Target | Notes |
|---|---|---|
| `WindyKnits/` | `WindyKnits.app` | Main SwiftUI app. All screens, models, importer, settings. |
| `WindyKnitsWidget/` | `WindyKnitsWidgetExtension.appex` | Lock Screen / Dynamic Island Live Activity only — no Home Screen widgets. |
| `Shared/` | compiled into BOTH targets | Anything that must be shared across the process boundary. |
| `WindyKnitsTests/` | `WindyKnitsTests.xctest` | Swift Testing (not XCTest). |

`Shared/` membership is what makes the App Group bridge work — `SharedStore`, `CounterIntents`, `CounterActivityAttributes`, `Palette` are all linked into both processes.

## Building and testing

`xcode-select -p` on this machine points at `/Library/Developer/CommandLineTools`, which has no `xcodebuild`. Every `xcodebuild` / `xcrun` invocation must override `DEVELOPER_DIR`:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project WindyKnits.xcodeproj -scheme WindyKnits \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build
```

Don't suggest `sudo xcode-select -switch` without asking — it's a global system change.

Prefer the registered `xcode` MCP server (`mcp__xcode__BuildProject`, `mcp__xcode__RunAllTests`, `mcp__xcode__RunSomeTests`, `mcp__xcode__GetBuildLog`, `mcp__xcode__RenderPreview`) over shelling out — it already has the right `DEVELOPER_DIR`. Schemes: `WindyKnits` (app + tests), `WindyKnitsWidgetExtension` (widget only).

### Tests use Swift Testing

```swift
@Suite("PatternStore", .serialized)
struct PatternStoreTests {
    init() { TestState.wipeAll() }
    @Test func newStoreStartsFromCleanDefaults() { ... #expect(...) }
}
```

- `@Suite(..., .serialized)` is mandatory for any suite that touches `UserDefaults.standard`, `SharedStore.defaults`, or the Keychain — they're global and tests would race otherwise.
- `TestState.wipeAll()` (in `WindyKnitsTests/TestSupport.swift`) clears app UserDefaults keys, Keychain, and the App Group suite. Its key constants are hand-mirrored from the production code — if you rename a storage key in `PatternStore` / `WindyKnitsSettings`, update `TestSupport.swift` too or the tests silently no-op.

## Architecture

### App Group bridge (the critical one)

App and Live Activity widget share state through App Group `group.dc.knitting.shared`. `SharedStore` is the single source of truth for counter keys (`counter.<projectId>.rows`, `.stitches`, `.history`, `.rowTexts`, etc.). The app uses `@AppStorage(..., store: SharedStore.defaults)`; the widget intents use `SharedStore.defaults.set(...)` directly.

Two consequences worth knowing before changing this code:

1. **`CounterScreen.reloadFromAppGroup()` on `scenePhase == .active`** — writes from the widget extension process don't fire in-process KVO in the app, so without this re-read the counter screen stays stale after the user taps +1 on the Lock Screen.
2. **`SharedStore.migrateFromStandardIfNeeded()` runs once at app launch** — older builds wrote `counter.*` keys to `UserDefaults.standard`; the migration copies them into the suite so upgrading users don't see resets. Don't remove it.

### Live Activity intents

`IncrementRowIntent`, `DecrementRowIntent`, `ResetRowsIntent` in `Shared/CounterIntents.swift` all conform to **`LiveActivityIntent`** (not plain `AppIntent`). This matters: `LiveActivityIntent` runs `perform()` in the app's process, so `Activity<...>.activities` is non-empty and `activity.update(...)` actually propagates to the Lock Screen. A plain `AppIntent` would run in the widget extension where the activity collection is empty and updates would silently no-op.

Don't add haptics inside these intents — iOS suppresses `CHHapticEngine` + UIKit feedback generators in background-launched intent processes. Haptics belong in `CounterScreen` (foreground only).

`authenticationPolicy = .alwaysAllowed` is explicit on each intent so iOS doesn't prompt for Face ID before running the Lock Screen +1.

### Pattern import has three tiers

`PatternLLMRefiner.resolve(settings:)` picks the highest-tier refiner the device can use:

1. **Apple Intelligence** (`AppleRefiner`, `#if canImport(FoundationModels)`, iOS 26+) — free, on-device, no consent needed.
2. **Claude** (`ClaudeRefiner`, model `claude-haiku-4-5-20251001`) — requires `WindyKnitsSettings.canUseCloud` (consent + API key in Keychain).
3. **Heuristic fallback** (`PatternImporter.refineSectionsHeuristic`) — used when refiner is nil OR when the LLM call errors mid-parse (in which case the displayed tier downgrades to `.basic(.llmFailed)`).

Both LLM tiers share `RefinerPrompts.systemPrompt` and `RefinerPrompts.userMessage(...)` so they classify identically — only the transport differs. Confidence floor is 0.6; batch size 8.

`ConsentSheet` only appears when Apple Intelligence is unavailable AND `settings.cloudConsent == nil` — see `ImportScreen.shouldAskConsent()`.

### Project store

`PatternStore` (`@Observable` singleton, persisted to UserDefaults) holds three things:

- `imported: [Project]` — user-imported / manually-created projects (mutable).
- `statusOverrides: [String: ProjectStatus]` — lets the user move sample projects (`SampleData.projects` is a read-only static) between active/queue/finished without mutating the source.
- `deleted: Set<String>` — sample-project IDs the user has deleted, so they don't reappear next launch.

`allProjects()` interleaves imported (newest first) → samples, filters by `deleted`, applies `statusOverrides`. Anywhere you read a project, use `store.project(id:)` rather than touching `SampleData.projects` directly so overrides are applied.

### Navigation

`RootView` holds one `NavCoordinator` per tab (`@Observable` wrappers around `NavigationPath`). Routes are defined as `enum Route` in `RootView.swift`; the `navigationDestinationForRoutes()` extension materializes them. Push with `nav.push(.project(id))`; the `resetTo(_:)` helper is used by the manual-pattern Save flow to clear the import stack and land on the new project's detail screen.

### Secrets

Anthropic API key is stored in Keychain (`WindyKnits.AnthropicAPIKey`) via the `Keychain` enum in `Settings.swift`. Cloud-parsing consent (`WindyKnits.cloudConsent.v1`) is a `Bool?` in `UserDefaults.standard` — `nil` means "not yet asked".

## Conventions in this codebase

- **Comments explain *why*, not *what*.** Most files (especially `CounterIntents.swift`, `SharedStore.swift`, `Models.swift`, `PatternImporter.swift`) have substantial inline rationale for non-obvious decisions. Preserve them when editing; match the style when adding new comments.
- **`nonisolated` on parser helpers** (`PatternImporter`) is deliberate so the importer can run off the main actor from background tasks.
- **`@Observable` + `.shared` singletons** for app-wide state (`PatternStore`, `WindyKnitsSettings`). Injected via `.environment(...)` in `WindyKnitsApp.swift`.
- **Sample data lives in `SampleData`** (in `Models.swift`). `p1` (Marigold Cardigan) is the default counter project and seeds the Today screen's "currently knitting" card.

## SwiftUI Canvas vs Simulator

When the user reports "the button doesn't work" or "nothing happens when I tap X", **first ask whether they're in Xcode Canvas preview or the Simulator** before debugging. Several past investigations chased runtime hypotheses that were actually `#Preview` wiring issues (constant `NavigationPath` bindings, missing `.navigationDestination` modifiers, missing `@Previewable @State`). The app and previews are not the same surface.
