//
//  HistoryScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import GRDB
import SwiftUI

struct HistoryScreen: View {
    @State private var records: [RecordModel] = []
    @State private var isLoading = false
    @State private var hasLoadedAll = false

    private let batchSize = 25

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty && !isLoading {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.badge.xmark")
                            .font(.title)
                        Text("noHistory")
                            .font(.headline)
                    }
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                                HistoryItemView(record: record)
                                    .onAppear {
                                        if index == records.count - 1 && !hasLoadedAll {
                                            loadMoreRecords()
                                        }
                                    }
                            }

                            if isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        } header: {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .navigationTitle("history")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if records.isEmpty {
                    loadInitialRecords()
                }
            }
            .onReceive(HistoryService.shared.objectWillChange) {
                refreshRecords()
            }
        }
    }

    private func loadInitialRecords() {
        records = []
        hasLoadedAll = false
        loadMoreRecords()
    }

    private func loadMoreRecords() {
        guard !isLoading && !hasLoadedAll else { return }

        isLoading = true

        let newRecords = HistoryService.shared.getAll(limit: batchSize, offset: records.count)

        records.append(contentsOf: newRecords)
        hasLoadedAll = newRecords.count < batchSize
        isLoading = false
    }

    private func refreshRecords() {
        let newRecords = HistoryService.shared.getAll(limit: records.count)
        records = newRecords
    }
}

struct HistoryItemView: View {
    var record: RecordModel

    @State private var manga: Manga?
    @State private var plugin: Plugin?
    @State private var isLoading: Bool = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                NavigationLink(destination: {
                    if let manga = manga,
                       let plugin = plugin
                    {
                        MangaDetailsScreen(plugin: plugin, manga: manga)
                    } else {
                        ErrorScreen(errorMessage: String(localized: "failedToLoadMangaDetails"))
                    }
                }) {
                    HStack(spacing: 10) {
                        MangaCoverView(coverUrl: manga?.cover, plugin: plugin)
                            .aspectRatio(3 / 4, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(manga?.title ?? record.mangaId)
                                .font(.headline)
                                .lineLimit(1)

                            HStack {
                                if let chapterTitle = record.chapterTitle {
                                    Text(chapterTitle)

                                } else if let chapterId = record.chapterId {
                                    Text("chapter \(chapterId)")
                                }

                                Text("•")
                                Text("page \(record.page + 1)")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                            Text(record.datetime.formatted())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .frame(height: 100)
        .onAppear {
            loadMangaData()
        }
    }

    private func loadMangaData() {
        plugin = PluginService.shared.getPlugin(record.pluginId)

        // Try to get manga from DbService
        if let mangaModel = getMangaModel(mangaId: record.mangaId, pluginId: record.pluginId),
           let infoData = mangaModel.info.data(using: .utf8)
        {
            do {
                manga = try JSONDecoder().decode(Manga.self, from: infoData)
            } catch {
                print("Failed to decode manga data: \(error)")
            }
        }

        isLoading = false
    }

    private func getMangaModel(mangaId: String, pluginId: String) -> MangaModel? {
        return try? DbService.shared.appDb?.read { db in
            try MangaModel
                .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                .fetchOne(db)
        }
    }
}
