//
//  PluginSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

struct PluginSettingsScreen: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        PluginSettingsScreenContent(pluginService: appState.pluginService)
    }
}

struct PluginSettingsScreenContent: View {
    @State private var showModal = false
    @ObservedObject var pluginService: PluginService

    var body: some View {
        List {
            SettingsHeaderView(image: Image(systemName: "puzzlepiece.fill"), color: .red, title: String(localized: "plugins"), description: String(localized: "pluginsDescription"))

            ForEach(pluginService.plugins) { plugin in
                NavigationLink(destination: {
                    PluginInfoScreen(plugin: plugin)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plugin.name ?? plugin.id)
                            if let version = plugin.version {
                                Text("v\(version)").smallTagStyle()
                            }
                        }
                        if let description = plugin.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    showModal = true
                }) {
                    Image(systemName: "plus.circle").foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $showModal) {
            AddPluginModal()
        }
    }
}
