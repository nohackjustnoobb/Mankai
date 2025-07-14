//
//  ContentView.swift
//  mankai
//
//  Created by Travis XU on 20/6/2025.
//

import SwiftUI

struct HomeTab: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\SavedData.updatesDate, order: .reverse)])
    private var saveds: FetchedResults<SavedData>

    @EnvironmentObject var appState: AppState

    @State private var mangas: [String: Manga] = [:]
    @State private var plugins: [String: Plugin] = [:]
    @State private var records: [String: RecordData] = [:]
    @State private var savedsDict: [String: SavedData] = [:]
    @State private var orders: [String] = []

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
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 110), spacing: 12)
                            ], spacing: 12
                        ) {
                            ForEach(orders, id: \.self) { key in
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
    }
}
