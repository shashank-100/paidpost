//
//  PaidPostApp.swift
//  Methods
//

import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct PaidPostApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // Let Google Sign-In handle its OAuth redirect (reversed
                    // client id scheme). No-op for other URLs / when SDK absent.
                    #if canImport(GoogleSignIn)
                    GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
                .task {
                    // UI-test / screenshot hook: skip onboarding + sign in via
                    // the Apple-review bypass so automation lands in the app.
                    // Guarded by a launch arg AND #if DEBUG — never runs in
                    // normal use and is compiled out of release builds.
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-uiTestAutoLogin") {
                        await store.uiTestAutoLogin()
                        return
                    }
                    #endif
                    await store.restoreSession()
                }
        }
    }
}
