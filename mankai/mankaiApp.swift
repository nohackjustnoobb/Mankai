//
//  mankai.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import SwiftUI

@main
struct mankai: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainScreen().environmentObject(appState)
        }
    }
}
