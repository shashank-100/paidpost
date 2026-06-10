//
//  MethodsApp.swift
//  Methods
//

import SwiftUI

@main
struct MethodsApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}
