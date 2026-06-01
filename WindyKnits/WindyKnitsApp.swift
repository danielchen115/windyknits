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

    init() {
        // Move any pre-existing UserDefaults.standard counter keys into the
        // App Group suite so the Lock Screen widget sees them.
        SharedStore.migrateFromStandardIfNeeded()
        // One-shot cleanup of legacy PatternStore keys and orphan
        // Live Activities / counter keys that no longer match a project.
        LaunchMigration.runIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(patternStore)
                .environment(settings)
        }
    }
}
