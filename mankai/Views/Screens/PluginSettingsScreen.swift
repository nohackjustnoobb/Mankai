//
//  PluginSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

struct PluginSettingsScreen: View {
    @State private var showModal = false
    @ObservedObject var pluginService: PluginService = PluginService.shared

    var body: some View {
        List {
            SettingsHeaderView(
                image: Image(systemName: "puzzlepiece.fill"), color: .red,
                title: String(localized: "plugins"),
                description: String(localized: "pluginsDescription")
            )

            ForEach(
                pluginService.plugins.sorted { plugin1, plugin2 in
                    let isPlugin1AppFs = plugin1 is AppDirPlugin
                    let isPlugin2AppFs = plugin2 is AppDirPlugin

                    if isPlugin1AppFs, !isPlugin2AppFs {
                        return true
                    } else if !isPlugin1AppFs, isPlugin2AppFs {
                        return false
                    } else {
                        return plugin1.name ?? plugin1.id < plugin2.name ?? plugin2.id
                    }
                }
            ) { plugin in
                NavigationLink(destination: {
                    PluginInfoScreen(plugin: plugin)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(plugin.name ?? plugin.id)
                            if let version = plugin.version {
                                Text("v\(version)")
                                    .smallTagStyle()
                            }

                            if let tag = plugin.tag {
                                Text(tag)
                                    .smallTagStyle()
                            }
                        }
                        if let description = plugin.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showModal = true
                }) {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showModal) {
            AddPluginModal()
        }
    }
}
