//
//  HistoryScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import CoreData
import SwiftUI

struct HistoryScreen: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordData.date, ascending: false)],
        animation: .default
    )
    private var records: FetchedResults<RecordData>

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    Text("noHistory")
                } else {
                    List {
                        Section {
                            ForEach(records, id: \.objectID) { record in
                                HistoryItemView(record: record)
                            }
                        } header: {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .navigationTitle("history")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct HistoryItemView: View {
    let record: RecordData

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
                    }
                }) {
                    HStack(spacing: 16) {
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
