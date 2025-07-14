//
//  HistoryScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import CoreData
import SwiftUI

struct HistoryScreen: View {
    @State private var records: [RecordData] = []
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
                            ForEach(records, id: \.objectID) { record in
                                HistoryItemView(record: record)
                                    .onAppear {
                                        if record.objectID == records.last?.objectID
                                            && !hasLoadedAll
                                        {
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
                setupObserver()
            }
            .onDisappear {
                removeObserver()
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

        let request: NSFetchRequest<RecordData> = RecordData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecordData.date, ascending: false)]
        request.fetchLimit = batchSize
        request.fetchOffset = records.count

        do {
            let newRecords = try DbService.shared.context.fetch(request)

            records.append(contentsOf: newRecords)
            hasLoadedAll = newRecords.count < batchSize
            isLoading = false
        } catch {
            print("Failed to fetch records: \(error)")
            isLoading = false
        }
    }

    private func refreshRecords() async {
        let request: NSFetchRequest<RecordData> = RecordData.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecordData.date, ascending: false)]
        request.fetchLimit = records.count

        do {
            let newRecords = try DbService.shared.context.fetch(request)
            records = newRecords
        } catch {
            print("Failed to refresh records: \(error)")
        }
    }

    private func setupObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: DbService.shared.context,
            queue: .main
        ) { _ in
            Task {
                await refreshRecords()
            }
        }
    }

    private func removeObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .NSManagedObjectContextObjectsDidChange,
            object: DbService.shared.context
        )
    }
}

struct HistoryItemView: View {
    @ObservedObject var record: RecordData

    @State private var manga: Manga?
    @State private var plugin: Plugin?
    @State private var isLoading: Bool = true

    @EnvironmentObject var appState: AppState

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
                            Text(manga?.title ?? record.target?.id ?? "nil")
                                .font(.headline)
                                .lineLimit(1)

                            HStack {
                                if let chapterTitle = record.chapterTitle {
                                    Text(chapterTitle)

                                } else if let chapterId = record.chapterId {
                                    Text("chapter \(chapterId)")
                                }

                                if let page = record.page as? Decimal {
                                    Text("•")
                                    Text("page \((page + 1).description)")
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                            if let date = record.date {
                                Text(date.formatted())
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
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
        guard let target = record.target else { return }

        if let pluginId = target.plugin {
            plugin = appState.pluginService.getPlugin(pluginId)
        }

        if let metaString = target.meta,
           let metaData = metaString.data(using: .utf8)
        {
            do {
                manga = try JSONDecoder().decode(Manga.self, from: metaData)
            } catch {
                print("Failed to decode manga data: \(error)")
            }
        }

        isLoading = false
    }
}
