//
//  ContentView.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import GRDB
import SwiftUI

private enum HomeMangaStatus: String, CaseIterable {
    case all
    case onGoing
    case ended
    case updated
}

struct HomeTab: View {
    private let pluginService = PluginService.shared

    @State private var mangas: [String: Manga] = [:]
    @State private var plugins: [String: Plugin] = [:]
    @State private var records: [String: RecordModel] = [:]
    @State private var saveds: [String: SavedModel] = [:]
    @State private var orders: [String] = []

    // Filter & Search
    @State private var searchText: String = ""
    @State private var hidePlugins: [String] = []
    @State private var status: HomeMangaStatus = .all
    @State private var filteredOrders: [String] = []
    @State private var showingFilters = false

    // Temp filter states for modal
    @State private var tempHidePlugins: [String] = []
    @State private var tempStatus: HomeMangaStatus = .all

    private var hasActiveFilters: Bool {
        !hidePlugins.isEmpty || status != .all
    }

    private var availablePlugins: [Plugin] {
        return pluginService.plugins.sorted { plugin1, plugin2 in
            let name1 = plugin1.name ?? plugin1.id
            let name2 = plugin2.name ?? plugin2.id
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if orders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "bookmark.slash")
                            .font(.title)
                        Text("noSavedManga")
                            .font(.headline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredOrders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                        Text("noResultsFound")
                            .font(.headline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 110), spacing: 12)
                            ], spacing: 12
                        ) {
                            ForEach(filteredOrders, id: \.self) { key in
                                if let manga = mangas[key],
                                   let plugin = plugins[key]
                                {
                                    NavigationLink(
                                        destination: MangaDetailsScreen(
                                            plugin: plugin, manga: manga
                                        )
                                    ) {
                                        MangaItemView(
                                            manga: manga,
                                            plugin: plugin,
                                            record: records[key],
                                            saved: saveds[key],
                                            showNotRead: true
                                        )
                                        .aspectRatio(3 / 5, contentMode: .fit)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingFilters = true
                    }) {
                        ZStack {
                            Image(systemName: "line.3.horizontal.decrease.circle")

                            if hasActiveFilters {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "searchSavedManga")
            .onChange(of: searchText) {
                filterManga()
            }
            .onAppear {
                updateSaved()
            }
            .onReceive(pluginService.objectWillChange) {
                updateSaved()
            }

            .onReceive(SavedService.shared.objectWillChange) {
                updateSaved()
            }
            .onReceive(HistoryService.shared.objectWillChange) {
                updateRecord()
            }
            .sheet(isPresented: $showingFilters) {
                NavigationView {
                    List {
                        Section {
                            Picker("status", selection: $tempStatus) {
                                Text("all")
                                    .tag(HomeMangaStatus.all)
                                Text("onGoing")
                                    .tag(HomeMangaStatus.onGoing)
                                Text("ended")
                                    .tag(HomeMangaStatus.ended)
                                Text("updated")
                                    .tag(HomeMangaStatus.updated)
                            }
                            .pickerStyle(.menu)
                        } header: {
                            Spacer(minLength: 0)
                        }

                        Section("hidePlugins") {
                            ForEach(availablePlugins, id: \.id) { plugin in
                                Button(action: {
                                    if tempHidePlugins.contains(plugin.id) {
                                        tempHidePlugins.removeAll { $0 == plugin.id }
                                    } else {
                                        tempHidePlugins.append(plugin.id)
                                    }
                                }) {
                                    HStack {
                                        Text(plugin.name ?? plugin.id)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if tempHidePlugins.contains(plugin.id) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        Section {
                            Button(
                                "reset",
                                role: .destructive,
                                action: {
                                    resetFilters()
                                    showingFilters = false
                                }
                            )
                        }
                    }
                    .navigationTitle("filters")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(action: {
                                tempHidePlugins = hidePlugins
                                tempStatus = status
                                showingFilters = false
                            }) {
                                Text("cancel")
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button(action: {
                                setFilters(hidePlugins: tempHidePlugins, status: tempStatus)
                                showingFilters = false
                            }) {
                                Text("done")
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
                .onAppear {
                    tempHidePlugins = hidePlugins
                    tempStatus = status
                }
            }
        }
    }

    private func updateSaved() {
        var mangas: [String: Manga] = [:]
        var plugins: [String: Plugin] = [:]
        var saveds: [String: SavedModel] = [:]

        let savedList: [SavedModel] = SavedService.shared.getAll()
        for saved in savedList {
            let key = "\(saved.pluginId)_\(saved.mangaId)"

            if let plugin = pluginService.getPlugin(saved.pluginId) {
                plugins[key] = plugin
            }

            if let mangaModel = try? DbService.shared.appDb?.read({ db in
                try saved.manga.fetchOne(db)
            }) {
                if let mangaData = mangaModel.info.data(using: .utf8),
                   let mangaDict = try? JSONSerialization.jsonObject(with: mangaData) as? [String: Any],
                   let manga = Manga(from: mangaDict)
                {
                    mangas[key] = manga
                }
            }

            saveds[key] = saved
        }

        self.mangas = mangas
        self.plugins = plugins
        self.saveds = saveds

        updateRecord()
    }

    private func updateRecord() {
        var records: [String: RecordModel] = [:]

        for (key, saved) in saveds {
            if let record = HistoryService.shared.get(mangaId: saved.mangaId, pluginId: saved.pluginId) {
                records[key] = record
            }
        }

        self.records = records

        sortSaved()
    }

    private func sortSaved() {
        let keys = mangas.keys

        let sortedKeys = keys.sorted { key1, key2 in
            let savedDate1 = saveds[key1]?.datetime
            let recordDate1 = records[key1]?.datetime
            let savedDate2 = saveds[key2]?.datetime
            let recordDate2 = records[key2]?.datetime

            let newerDate1 = [savedDate1, recordDate1].compactMap { $0 }.max()
            let newerDate2 = [savedDate2, recordDate2].compactMap { $0 }.max()

            switch (newerDate1, newerDate2) {
            case (let date1?, let date2?):
                return date1 > date2
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }

        orders = sortedKeys
        filterManga()
    }

    private func filterManga() {
        var filtered = orders

        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { key in
                mangas[key]?.title?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        // Filter by hidden plugins
        if !hidePlugins.isEmpty {
            filtered = filtered.filter { key in
                let pluginId = key.split(separator: "_").first.map(String.init) ?? ""
                return !hidePlugins.contains(pluginId)
            }
        }

        // Filter by status
        if status != .all {
            filtered = filtered.filter { key in
                guard let manga = mangas[key], let saved = saveds[key] else { return false }

                switch status {
                case .all:
                    return true
                case .onGoing:
                    return manga.status == .onGoing
                case .ended:
                    return manga.status == .ended
                case .updated:
                    return saved.updates
                }
            }
        }

        filteredOrders = filtered
    }

    private func setStatus(_ newStatus: HomeMangaStatus) {
        guard newStatus != status else { return }
        status = newStatus
        filterManga()
    }

    private func removeHiddenPlugin(_ pluginId: String) {
        hidePlugins.removeAll { $0 == pluginId }
        filterManga()
    }

    private func setFilters(hidePlugins: [String], status: HomeMangaStatus) {
        if self.hidePlugins != hidePlugins {
            self.hidePlugins = hidePlugins
        }

        if self.status != status {
            self.status = status
        }

        filterManga()
    }

    private func resetFilters() {
        tempHidePlugins = []
        tempStatus = .all
        setFilters(hidePlugins: [], status: .all)
    }
}
