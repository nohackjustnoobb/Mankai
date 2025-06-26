//
//  SettingsTab.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

struct SettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            List {
                Section {
                    NavigationLink(
                        destination: PluginSettingsScreen()
                    ) {
                        Label("plugins", systemImage: "puzzlepiece.fill")
                            .labelStyle(ColorfulIconLabelStyle(color: .red))
                    }
                    NavigationLink(
                        destination: DebugScreen()
                    ) {
                        Label("debug", systemImage: "curlybraces")
                            .labelStyle(ColorfulIconLabelStyle(color: .blue))
                    }
                }
            }
            .navigationTitle("settings")
        }
    }
}
