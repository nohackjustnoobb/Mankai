//
//  MangaDetailsScreen.swift
//  mankai
//
//  Created by Travis XU on 29/6/2025.
//

import SwiftUI
import WrappingHStack

struct MangaDetailsScreen: View {
    @ObservedObject var plugin: Plugin
    let manga: Manga

    @State private var detailedManga: DetailedManga? = nil

    @State private var showingChaptersModal = false
    @State private var selectedChapterKey: String? = nil
    @State private var isReversed = true

    @State private var readerChapterKey: String? = nil
    @State private var readerChapter: Chapter? = nil
    @State private var readerPage: Int? = nil
    @State private var showReaderScreen = false

    @State private var isUpdateMangaModalPresented = false
    @State private var isUpdateChaptersModalPresented = false

    @State private var selectedGenre: Genre? = nil
    @State private var showPluginLibraryScreen = false

    @State private var searchQuery: String? = nil
    @State private var showPluginSearchScreen = false

    @Environment(\.dismiss) private var dismiss

    @State private var record: RecordModel? = nil
    @State private var saved: SavedModel? = nil

    init(plugin: Plugin, manga: Manga) {
        self.plugin = plugin
        self.manga = manga
    }

    private func updateRecord() {
        record = HistoryService.shared.get(mangaId: manga.id, pluginId: plugin.id)
    }

    private func updateSaved() {
        saved = SavedService.shared.get(mangaId: manga.id, pluginId: plugin.id)
    }

    private func navigateToChapter(_ chapter: Chapter, page: Int? = nil, chaptersKey: String? = nil) {
        readerChapter = chapter
        readerChapterKey = chaptersKey ?? selectedChapterKey
        readerPage = page

        showingChaptersModal = false
        showReaderScreen = true
    }

    private func handleReadContinueAction() {
        if let record = record {
            if let detailedManga = detailedManga {
                for (chaptersKey, chapters) in detailedManga.chapters {
                    if let chapter = chapters.first(where: {
                        $0.id == record.chapterId
                    }) {
                        navigateToChapter(
                            chapter, page: record.page, chaptersKey: chaptersKey
                        )
                        break
                    }
                }
            }
        } else {
            if let detailedManga = detailedManga {
                let sortedChapters = Array(detailedManga.chapters).sorted {
                    $0.value.count > $1.value.count
                }

                if let chapters = sortedChapters.first,
                   let chapter = chapters.value.first
                {
                    navigateToChapter(chapter, chaptersKey: chapters.key)
                }
            }
        }
    }

    private func handleBookmarkAction() {
        Task {
            let result: Bool?

            if saved != nil {
                result = await SavedService.shared.remove(mangaId: manga.id, pluginId: plugin.id)
            } else {
                let newSaved = SavedModel(
                    mangaId: manga.id,
                    pluginId: plugin.id,
                    datetime: Date(),
                    updates: false,
                    latestChapter: manga.latestChapter?.encode() ?? ""
                )

                let mangaInfo: String
                if let mangaData = try? JSONEncoder().encode(manga) {
                    mangaInfo = String(data: mangaData, encoding: .utf8) ?? "{}"
                } else {
                    mangaInfo = "{}"
                }

                let mangaModel = MangaModel(
                    mangaId: manga.id,
                    pluginId: plugin.id,
                    info: mangaInfo
                )

                result = await SavedService.shared.add(saved: newSaved, manga: mangaModel)
            }

            if result == nil || !result! {
                Logger.ui.error("Failed to delete or create SavedData")
            }
        }
    }

    var info: some View {
        List {
            if let remarks = detailedManga?.remarks, !remarks.isEmpty {
                Section("remarks") {
                    Text(remarks)
                }
            }

            Section {} header: {
                VStack {
                    MangaCoverView(coverUrl: detailedManga?.title ?? manga.cover, plugin: plugin)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .padding(.horizontal)

                    Text(detailedManga?.title ?? detailedManga?.id ?? manga.title ?? manga.id)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .foregroundColor(.primary)

                    if let authors = detailedManga?.authors,
                       !authors.isEmpty
                    {
                        HStack(spacing: 4) {
                            HStack(spacing: 4) {
                                ForEach(authors, id: \.self) { author in
                                    Button(action: {
                                        searchQuery = author
                                        showPluginSearchScreen = true
                                    }) {
                                        Text(author)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Image(systemName: "chevron.right")
                                .foregroundColor(.primary.opacity(0.7))
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .textCase(.none)
            }
            .listRowInsets(EdgeInsets())
            .padding(.top)

            Section {
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        if let updatedAt = detailedManga?.updatedAt {
                            Text(updatedAt.formatted(date: .abbreviated, time: .omitted))
                            Text("•")
                        }

                        if let chapters = detailedManga?.chapters {
                            Text("\(chapters.values.flatMap { $0 }.count) chapters")
                        }

                        if let status = detailedManga?.status {
                            Text("•")
                            Text(statusText(status))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(action: handleReadContinueAction) {
                            HStack {
                                Image(systemName: "book.pages.fill")
                                Text(record != nil ? "continue" : "read")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        Button(action: handleBookmarkAction) {
                            HStack {
                                Image(
                                    systemName: saved != nil
                                        ? "bookmark.slash.fill" : "bookmark.fill")
                                Text(saved != nil ? "remove" : "bookmark")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(saved != nil ? nil : .accent)
                        .frame(maxWidth: .infinity)
                    }

                    if let record = record {
                        HStack(spacing: 4) {
                            Text("lastRead")

                            if let chapterTitle = record.chapterTitle {
                                Text("•")
                                Text(chapterTitle)
                                    .lineLimit(1)
                            } else {
                                Text("•")
                                Text("chapter \(record.chapterId)")
                                    .lineLimit(1)
                            }

                            Text("•")
                            Text("page \((record.page + 1).description)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Spacer(minLength: 0)
            }

            if let detailedManga = detailedManga {
                if let description = detailedManga.description {
                    Section {
                        Text(description)
                    } header: {
                        Text("description")
                            .padding(.top)
                    }
                }
            }

            if let genres = detailedManga?.genres,
               !genres.isEmpty
            {
                Section {
                    WrappingHStack(genres, id: \.self, lineSpacing: 8) { genre in
                        Button(action: {
                            selectedGenre = genre
                            showPluginLibraryScreen = true
                        }) {
                            Text(LocalizedStringKey(genre.rawValue))
                                .genreTagStyle()
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding()
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("genres")
                        .padding(.top)
                }
            }

            if let detailedManga = detailedManga,
               !detailedManga.chapters.isEmpty
            {
                Section {
                    ForEach(
                        Array(detailedManga.chapters).sorted { $0.value.count > $1.value.count },
                        id: \.key
                    ) { key, chapters in
                        Button(action: {
                            selectedChapterKey = key
                            showingChaptersModal = UIDevice.isIPhone
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(LocalizedStringKey(key))
                                            .foregroundColor(.primary)

                                        Text("\(chapters.count) chapters")
                                            .smallTagStyle()
                                    }

                                    if let latestChapter = chapters.last {
                                        HStack(spacing: 4) {
                                            Text("latest")
                                                .font(.caption)
                                                .foregroundColor(.primary)

                                            Text(latestChapter.title ?? latestChapter.id)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }

                                Spacer()

                                Image(systemName: "list.bullet")
                                    .foregroundColor(.secondary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("chapters")
                        .padding(.top)
                }
            }
        }
    }

    var body: some View {
        Group {
            if UIDevice.isIPad {
                HStack(spacing: 0) {
                    info
                        .frame(maxWidth: 400)

                    if let selectedChapterKey = selectedChapterKey,
                       let chapters = detailedManga?.chapters[selectedChapterKey]
                    {
                        List {
                            Section {
                                if chapters.isEmpty {
                                    Text("noChaptersAvailable")
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(isReversed ? chapters.reversed() : chapters, id: \.id) {
                                        chapter in
                                        Button(action: {
                                            navigateToChapter(chapter)
                                        }) {
                                            HStack {
                                                Text(chapter.title ?? chapter.id)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                                Image(systemName: (chapter.locked ?? false) ? "lock.fill" : "chevron.right")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .disabled(chapter.locked ?? false)
                                    }
                                }

                            } header: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(LocalizedStringKey(selectedChapterKey))
                                        Text("\(chapters.count) chapters")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    HStack {
                                        Button(action: {
                                            isReversed.toggle()
                                        }) {
                                            Image(
                                                systemName: isReversed
                                                    ? "arrow.up"
                                                    : "arrow.down"
                                            )
                                            .font(.headline)
                                        }
                                        .buttonStyle(.plain)

                                        if plugin is ReadWriteFsPlugin {
                                            Button(action: {
                                                isUpdateChaptersModalPresented = true
                                            }) {
                                                Image(systemName: "pencil")
                                                    .font(.headline)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemGroupedBackground))
                    }
                }
            } else {
                info
            }
        }
        .listSectionSpacing(0)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(detailedManga?.title ?? detailedManga?.id ?? manga.title ?? manga.id)
        .sheet(isPresented: $showingChaptersModal) { [detailedManga, selectedChapterKey] in
            if let detailedManga = detailedManga,
               let selectedChapterKey = selectedChapterKey
            {
                ChaptersModal(
                    plugin: plugin,
                    manga: detailedManga,
                    chaptersKey: selectedChapterKey,
                    onNavigateToChapter: navigateToChapter
                )
            }
        }
        .sheet(isPresented: $isUpdateMangaModalPresented) { [detailedManga] in
            if let detailedManga = detailedManga,
               let readWritePlugin = plugin as? ReadWriteFsPlugin
            {
                UpdateMangaModal(plugin: readWritePlugin, manga: detailedManga)
            }
        }
        .sheet(isPresented: $isUpdateChaptersModalPresented) {
            [detailedManga, selectedChapterKey] in
            if let detailedManga = detailedManga,
               let selectedChapterKey = selectedChapterKey,
               let readWritePlugin = plugin as? ReadWriteFsPlugin
            {
                UpdateChaptersModal(
                    plugin: readWritePlugin, manga: detailedManga, chaptersKey: selectedChapterKey,
                    isRootOfSheet: true
                )
            }
        }
        .navigationDestination(isPresented: $showReaderScreen) {
            if let readerChapter = readerChapter,
               let readerChapterKey = readerChapterKey,
               let detailedManga = detailedManga
            {
                ReaderScreen(
                    plugin: plugin,
                    manga: detailedManga,
                    chaptersKey: readerChapterKey,
                    chapter: readerChapter,
                    initialPage: readerPage
                )
            }
        }
        .navigationDestination(isPresented: $showPluginLibraryScreen) {
            if let selectedGenre = selectedGenre {
                PluginLibraryScreen(plugin: plugin, selectedGenre: selectedGenre)
            }
        }
        .navigationDestination(isPresented: $showPluginSearchScreen) {
            if let searchQuery = searchQuery {
                PluginSearchScreen(plugin: plugin, query: searchQuery)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(detailedManga?.title ?? detailedManga?.id ?? manga.title ?? manga.id)
                        .font(.headline)
                    Text(plugin.name ?? plugin.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if plugin is ReadWriteFsPlugin {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isUpdateMangaModalPresented = true }) {
                        Image(systemName: "pencil.circle")
                    }
                }
            }
        }
        .onAppear {
            loadDetailedManga()
            updateRecord()
            updateSaved()
        }
        .onReceive(plugin.objectWillChange) {
            loadDetailedManga()
        }
        .onReceive(SavedService.shared.objectWillChange) {
            updateSaved()
        }
        .onReceive(HistoryService.shared.objectWillChange) {
            updateRecord()
        }
        .apply {
            if UIDevice.isIPad {
                $0.toolbarBackground(.visible, for: .navigationBar)
            } else {
                $0
            }
        }
    }

    private func loadDetailedManga() {
        Task {
            do {
                detailedManga = try await plugin.getDetailedManga(manga.id)
                selectedChapterKey =
                    Array(detailedManga!.chapters).sorted { $0.value.count > $1.value.count }
                        .first?.key
            } catch {
                if !(plugin is ReadWriteFsPlugin) {
                    Logger.ui.error("Failed to load detailed manga", error: error)
                }

                dismiss()
            }
        }
    }
}
