//
//  MainScreen.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import SwiftUI

struct MainScreen: View {
    var body: some View {
        ZStack {
            TabView {
                HomeTab()
                    .tabItem {
                        Label("home", systemImage: "house")
                    }
                LibraryTab()
                    .tabItem {
                        Label("library", systemImage: "books.vertical.fill")
                    }
                SettingsTab()
                    .tabItem {
                        Label("settings", systemImage: "gearshape")
                    }
            }

            NotificationContainerView()
                .allowsHitTesting(true)
        }
    }
}
