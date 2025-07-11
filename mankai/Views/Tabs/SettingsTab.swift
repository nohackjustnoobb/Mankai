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
        NavigationStack {
            List {
                Section {
                    NavigationLink(
                        destination: GeneralSettingsScreen()
                    ) {
                        Label("general", systemImage: "gear")
                            .labelStyle(ColorfulIconLabelStyle(color: .gray))
                    }

                    NavigationLink(
                        destination: ReaderSettingsScreen()
                    ) {
                        Label("reader", systemImage: "book.pages.fill")
                            .labelStyle(ColorfulIconLabelStyle(color: .orange))
                    }
                }

                Section {
                    NavigationLink(
                        destination: PluginSettingsScreen()
                    ) {
                        Label("plugins", systemImage: "puzzlepiece.fill")
                            .labelStyle(ColorfulIconLabelStyle(color: .red, imageScale: .small))
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
