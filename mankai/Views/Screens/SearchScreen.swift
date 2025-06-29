//
//  SearchScreen.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

struct SearchScreen: View {
    let query: String
    @EnvironmentObject var appState: AppState

    var body: some View {
        SearchScreenContent(query: query, pluginService: appState.pluginService)
    }
}

private struct SearchScreenContent: View {
    let query: String

    @ObservedObject var pluginService: PluginService
    @State private var pluginsSearch: [String: [Manga]]? = nil

    var body: some View {
        Group {
            if let pluginsSearch = pluginsSearch {
                ScrollView {
                    LazyVStack {
                        ForEach(Array(pluginsSearch), id: \.key) { key, mangas in
                            MangasRowListView(
                                mangas: mangas,
                                pluginId: key,
                                query: query
                            )
                        }
                    }
                    .padding()
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("search")
                        .font(.headline)
                    Text(query)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            updatePlugins()
        }
        .onReceive(pluginService.objectWillChange) {
            updatePlugins()
        }
    }

    private func updatePlugins() {
        let plugins = pluginService.plugins

        var keysSet = Set(pluginsSearch?.keys as? [String] ?? [])
        for plugin in plugins {
            let key = plugin.id
            keysSet.remove(key)

            if pluginsSearch?[key] != nil {
                continue
            }

            Task {
                do {
                    let mangas = try await plugin.search(query, page: 1)

                    if self.pluginsSearch == nil {
                        self.pluginsSearch = [:]
                    }

                    self.pluginsSearch![key] = mangas
                } catch {
                    // TODO: show an alert
                    print("Failed to get list from plugin \(key): \(error)")
                }
            }
        }

        for key in keysSet {
            pluginsSearch?.removeValue(forKey: key)
        }
    }
}
