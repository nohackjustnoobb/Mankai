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
                // TODO: plugin info page
                Text(plugin.id)
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
