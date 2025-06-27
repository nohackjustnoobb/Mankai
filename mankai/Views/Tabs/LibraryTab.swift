//
//  LibraryTab.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

struct LibraryTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        LibraryTabContent(pluginService: appState.pluginService)
    }
}

private struct LibraryTabContent: View {
    @ObservedObject var pluginService: PluginService
    @State var pluginsList: [String: [Manga]]? = nil
    @State var query: String = ""
    @State var searchSuggestions: [String] = []
    @State var searchTask: Task<Void, Never>? = nil
    @State var navigateToSearch: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let pluginsList = pluginsList {
                    ScrollView {
                        LazyVStack {
                            ForEach(Array(pluginsList), id: \.key) { key, mangas in
                                MangasRowListView(
                                    mangas: mangas,
                                    pluginId: key
                                )
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("library")
            .onAppear {
                updatePlugins()
            }
            .onReceive(pluginService.objectWillChange) {
                updatePlugins()
            }
            .searchable(text: $query, prompt: "searchManga") {
                ForEach(searchSuggestions, id: \.self) { suggestion in
                    Label(suggestion, systemImage: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .searchCompletion(suggestion)
                }
            }
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: query) { newQuery in
                getSearchSuggestions(for: newQuery)
            }
            .onDisappear {
                searchTask?.cancel()
            }
            .navigationDestination(
                isPresented: $navigateToSearch,
                destination: {
                    SearchScreen(query: query)
                }
            )
        }
    }

    private func updatePlugins() {
        let plugins = pluginService.plugins

        var keysSet = Set(pluginsList?.keys as? [String] ?? [])
        for plugin in plugins {
            let key = plugin.id
            keysSet.remove(key)

            if pluginsList?[key] != nil {
                continue
            }

            Task {
                do {
                    let mangas = try await plugin.getList(page: 1, genre: .all, status: .any)

                    if self.pluginsList == nil {
                        self.pluginsList = [:]
                    }

                    self.pluginsList![key] = mangas
                } catch {
                    // TODO: show an alert
                    print("Failed to get list from plugin \(key): \(error)")
                }
            }
        }

        for key in keysSet {
            pluginsList?.removeValue(forKey: key)
        }
    }

    private func getSearchSuggestions(for query: String) {
        // Cancel previous search task
        searchTask?.cancel()

        guard !query.isEmpty else {
            searchSuggestions = []
            return
        }

        searchTask = Task {
            // Add debouncing delay
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            guard !Task.isCancelled else { return }

            var allSuggestions: Set<String> = []

            // Get suggestions from all available plugins
            for plugin in pluginService.plugins {
                guard !Task.isCancelled else { break }

                do {
                    let suggestions = try await plugin.getSuggestions(query)
                    allSuggestions.formUnion(suggestions)
                } catch {
                    // Continue with other plugins if one fails
                    print("Failed to get suggestions from plugin \(plugin.id): \(error)")
                }
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.searchSuggestions = Array(allSuggestions)
            }
        }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        navigateToSearch = true
    }
}
