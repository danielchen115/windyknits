//
//  WindyKnitsApp.swift
//  WindyKnits
//
//  Created by Daniel Chen on 5/19/26.
//

import SwiftUI

@main
struct WindyKnitsApp: App {
    @State private var patternStore = PatternStore.shared
    @State private var settings = WindyKnitsSettings.shared
    @State private var flags = FeatureFlags.shared
    @State private var account = UserAccount.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Move any pre-existing UserDefaults.standard counter keys into the
        // App Group suite so the Lock Screen widget sees them.
        SharedStore.migrateFromStandardIfNeeded()
        // One-shot cleanup of legacy PatternStore keys and orphan
        // Live Activities / counter keys that no longer match a project.
        LaunchMigration.runIfNeeded()
        // UI-test launch arguments (e.g. `--ui-test-reset`) get applied
        // before the first frame so XCUITest scenarios see a known state.
        // Release builds compile this out — `LaunchArguments` is Debug-only.
        #if DEBUG
        LaunchArguments.applyIfNeeded()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if account.isSignedIn {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environment(patternStore)
            .environment(settings)
            .environment(flags)
            .environment(account)
            // Catches credentials the user revoked from iOS Settings →
            // Apple ID → Sign in with Apple while the app was closed.
            // Re-checked on scene activation so we also catch revocations
            // that happen while the app is in the background.
            .task { await account.refreshCredentialState() }
            .onChange(of: scenePhase) { _, new in
                if new == .active {
                    Task { await account.refreshCredentialState() }
                }
            }
        }
    }
}
