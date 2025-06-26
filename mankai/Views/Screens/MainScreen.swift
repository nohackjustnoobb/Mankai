//
//  MainScreen.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import SwiftUI

struct MainScreen: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            HomeTab()
                .tabItem {
                    Label("home", systemImage: "house")
                }
            LibraryTab()
                .tabItem {
                    Label("library", systemImage: "book")
                }
            SearchTab()
                .tabItem {
                    Label("search", systemImage: "magnifyingglass")
                }
            SettingsTab()
                .tabItem {
                    Label("settings", systemImage: "gearshape")
                }
        }
    }
}
