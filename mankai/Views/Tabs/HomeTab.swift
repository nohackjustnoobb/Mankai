//
//  ContentView.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import SwiftUI

private enum HomeMangaStatus: String, CaseIterable {
    case all
    case onGoing
    case ended
    case updated
}

struct HomeTab: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SavedData.updatesDate, order: .reverse)])
    private var saveds: FetchedResults<SavedData>

    @EnvironmentObject var appState: AppState

    @State private var mangas: [String: Manga] = [:]
    @State private var plugins: [String: Plugin] = [:]
    @State private var records: [String: RecordData] = [:]
    @State private var savedsDict: [String: SavedData] = [:]
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
        return appState.pluginService.plugins.sorted { plugin1, plugin2 in
            let name1 = plugin1.name ?? plugin1.id
            let name2 = plugin2.name ?? plugin2.id
            return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
        }
    }

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: DbService.shared.context,
            queue: .main
        ) { _ in
            loadSavedManga()
        }
    }

    private func removeObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .NSManagedObjectContextObjectsDidChange,
            object: DbService.shared.context
        )
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
                                            saved: savedsDict[key],
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
            .onReceive(appState.pluginService.objectWillChange) {
                loadSavedManga()
            }
            .onAppear {
                loadSavedManga()
                setupObserver()
            }
            .onDisappear {
                removeObserver()
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

    private func loadSavedManga() {
        var mangas: [String: Manga] = [:]
        var plugins: [String: Plugin] = [:]
        var savedsDict: [String: SavedData] = [:]
        var records: [String: RecordData] = [:]

        for saved in saveds {
            guard let target = saved.target,
                  let pluginId = target.plugin,
                  let plugin = appState.pluginService.getPlugin(pluginId),
                  let metaString = target.meta,
                  let metaData = metaString.data(using: .utf8),
                  let mangaId = target.id
            else {
                continue
            }

            do {
                let manga = try JSONDecoder().decode(Manga.self, from: metaData)

                let key = "\(pluginId)_\(mangaId)"
                savedsDict[key] = saved
                plugins[key] = plugin
                mangas[key] = manga

                if let record = target.record {
                    records[key] = record
                }

            } catch {
                print("Failed to decode saved manga: \(error)")
            }
        }

        self.mangas = mangas
        self.plugins = plugins
        self.savedsDict = savedsDict
        self.records = records

        sortSaved()
    }

    private func sortSaved() {
        let keys = mangas.keys

        let sortedKeys = keys.sorted { key1, key2 in
            let savedDate1 = savedsDict[key1]?.updatesDate
            let recordDate1 = records[key1]?.date
            let savedDate2 = savedsDict[key2]?.updatesDate
            let recordDate2 = records[key2]?.date

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
                if let saved = savedsDict[key],
                   let target = saved.target,
                   let targetMeta = target.meta
                {
                    return targetMeta.localizedCaseInsensitiveContains(searchText)
                }
                return false
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
                guard let manga = mangas[key], let saved = savedsDict[key] else { return false }

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
