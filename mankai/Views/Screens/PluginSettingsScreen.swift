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
            ForEach(pluginService.plugins) { plugin in
                NavigationLink(destination: {
                    PluginInfoScreen(plugin: plugin)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plugin.name ?? plugin.id)
                            if let version = plugin.version {
                                SmallTag(text: String(localized: "v\(version)"))
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("plugins")
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
