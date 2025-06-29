//
//  PluginSearchScreen.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

struct PluginSearchScreen: View {
    let plugin: Plugin
    let query: String

    @EnvironmentObject var appState: AppState

    var body: some View {
        PluginSearchScreenContent(
            plugin: plugin, query: query, pluginService: appState.pluginService)
    }
}

private struct PluginSearchScreenContent: View {
    let plugin: Plugin
    let query: String
    @ObservedObject var pluginService: PluginService

    @State var isLoading: Bool = false
    @State var mangas: [UInt: [Manga]] = [:]

    private var allMangas: [Manga] {
        let sortedKeys = mangas.keys.sorted()
        return sortedKeys.flatMap { mangas[$0] ?? [] }
    }

    var body: some View {
        ScrollView {
            if allMangas.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVStack {
                    MangasListView(mangas: allMangas, plugin: plugin)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            search()
                        }
                }
                .padding()
            }
        }
        .navigationTitle("search")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(plugin.name ?? plugin.id)
                        .font(.headline)
                    Text(query)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            search()
        }
        .onReceive(pluginService.objectWillChange) {
            search()
        }
    }

    private func search() {
        if isLoading {
            return
        }

        let maxPage = mangas.keys.max() ?? 0

        // reach the end of the list
        if mangas[maxPage]?.count == 0 {
            return
        }

        let page = maxPage + 1

        isLoading = true
        Task {
            do {
                let result = try await plugin.search(query, page: page)

                mangas[page] = result
                isLoading = false
            } catch {
                // TODO: show an alert
                isLoading = false
                print("Search failed: \(error)")
            }
        }
    }
}
