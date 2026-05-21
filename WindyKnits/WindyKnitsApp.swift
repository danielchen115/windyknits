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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(patternStore)
                .environment(settings)
        }
    }
}
