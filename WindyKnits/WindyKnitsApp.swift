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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(patternStore)
                .environment(settings)
        }
    }
}
