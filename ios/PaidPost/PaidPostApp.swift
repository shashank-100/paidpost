//
//  PaidPostApp.swift
//  Methods
//

import SwiftUI

@main
struct PaidPostApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .task {
                    // UI-test / screenshot hook: skip onboarding + sign in via
                    // the Apple-review bypass so automation lands in the app.
                    // Guarded by a launch arg — never runs in normal use.
                    if ProcessInfo.processInfo.arguments.contains("-uiTestAutoLogin") {
                        await store.uiTestAutoLogin()
                    } else {
                        await store.restoreSession()
                    }
                }
        }
    }
}
