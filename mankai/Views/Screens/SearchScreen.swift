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
    @State private var plugins: [Plugin] = []

    var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(plugins) { plugin in
                    PluginSearchMangasRowListView(query: query, plugin: plugin)
                }
            }
            .padding()
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
        plugins = pluginService.plugins
    }
}

struct PluginSearchMangasRowListView: View {
    let query: String

    @ObservedObject var plugin: Plugin
    @State var mangas: [Manga]? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    func loadMangas() {
        Task {
            do {
                mangas = try await plugin.search(query, page: 1)
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    var body: some View {
        MangasRowListView(
            mangas: mangas,
            plugin: plugin,
            query: query
        )
        .onAppear {
            loadMangas()
        }
        .onReceive(plugin.objectWillChange) {
            loadMangas()
        }
        .alert("failedToSearchManga", isPresented: $showErrorAlert) {
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
