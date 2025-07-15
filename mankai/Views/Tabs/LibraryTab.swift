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
    @State var plugins: [Plugin] = []

    @State var query: String = ""
    @State var searchSuggestions: [String] = []
    @State var searchTask: Task<Void, Never>? = nil
    @State var navigateToSearch: Bool = false
    @State private var isUpdateMangaModalPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(plugins) { plugin in
                        PluginListMangasRowListView(plugin: plugin)
                    }
                }
                .padding()
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
            .onChange(of: query, initial: false) { _, newQuery in
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isUpdateMangaModalPresented = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $isUpdateMangaModalPresented) {
                UpdateMangaModal()
            }
        }
    }

    private func updatePlugins() {
        plugins = pluginService.plugins.sorted { plugin1, plugin2 in
            let name1 = plugin1.name ?? plugin1.id
            let name2 = plugin2.name ?? plugin2.id
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
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

            self.searchSuggestions = Array(allSuggestions)
        }
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        navigateToSearch = true
    }
}

private struct PluginListMangasRowListView: View {
    @ObservedObject var plugin: Plugin
    @State var mangas: [Manga]? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    func loadMangas() {
        Task {
            do {
                mangas = try await plugin.getList(page: 1, genre: .all, status: .any)

            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    var body: some View {
        MangasRowListView(
            mangas: mangas,
            plugin: plugin
        )
        .onAppear {
            loadMangas()
        }
        .onReceive(plugin.objectWillChange) {
            loadMangas()
        }
        .alert("failedToLoadMangas", isPresented: $showErrorAlert) {
            Button("ok") {
                errorMessage = ""
            }
        } message: {
            if !errorMessage.isEmpty {
                Text(errorMessage)
            }
        }
    }
}
