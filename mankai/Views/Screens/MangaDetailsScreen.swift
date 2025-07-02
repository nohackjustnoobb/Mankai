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
    @State private var selectedChapter: Chapter? = nil
    @State private var showReaderScreen = false
    @State private var isUpdateMangaModalPresented = false

    @Environment(\.dismiss) private var dismiss

    func navigateToChapter(_ chapter: Chapter) {
        selectedChapter = chapter
        showingChaptersModal = false
        showReaderScreen = true
    }

    var info: some View {
        List {
            Section {} header: {
                VStack {
                    MangaCoverView(coverUrl: manga.cover, plugin: plugin)
                        .aspectRatio(3 / 4, contentMode: .fit)
                        .padding(.horizontal)
                        .padding(.horizontal)

                    Text(manga.title ?? manga.id)
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
                                    Button(action: {}) {
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
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "book.pages.fill")
                                Text("read")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                        Button(action: {}) {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                Text("save")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
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
                        Button(action: {}) {
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

            if let detailedManga = detailedManga {
                Section {
                    ForEach(
                        Array(detailedManga.chapters).filter { $0.value.count > 0 }.sorted {
                            $0.value.count > $1.value.count
                        },
                        id: \.key
                    ) { key, chapters in
                        Button(action: {
                            selectedChapterKey = key
                            showingChaptersModal = UIDevice.isIPhone
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        Text(LocalizedStringKey(key))
                                            .foregroundColor(.primary)

                                        Text("\(chapters.count) chapters")
                                            .smallTagStyle()
                                    }

                                    if let latestChapter = chapters.last {
                                        HStack {
                                            Text("latest")
                                                .font(.caption)
                                                .foregroundColor(.primary)

                                            Text(latestChapter.title ?? latestChapter.id ?? "nil")
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
                                ForEach(isReversed ? chapters.reversed() : chapters, id: \.id) {
                                    chapter in
                                    Button(action: {
                                        navigateToChapter(chapter)
                                    }) {
                                        HStack {
                                            Text(chapter.title ?? chapter.id ?? "nil")
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
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

                                    Button(action: {
                                        isReversed.toggle()
                                    }) {
                                        Image(
                                            systemName: isReversed
                                                ? "arrow.counterclockwise"
                                                : "arrow.clockwise"
                                        )
                                        .font(.headline)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            } else {
                info
            }
        }
        .listSectionSpacing(0)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(manga.title ?? manga.id)
        .sheet(isPresented: $showingChaptersModal) { [selectedChapterKey] in
            ChaptersModal(
                manga: detailedManga!,
                chaptersKey: selectedChapterKey!,
                chapters: detailedManga!.chapters[selectedChapterKey!]!,
                onNavigateToChapter: navigateToChapter
            )
        }
        .sheet(isPresented: $isUpdateMangaModalPresented) { [detailedManga] in
            if let detailedManga = detailedManga {
                UpdateMangaModal(plugin: plugin as? ReadWriteFsPlugin, manga: detailedManga)
            }
        }
        .navigationDestination(isPresented: $showReaderScreen) {
            if let selectedChapter = selectedChapter,
               let selectedChapterKey = selectedChapterKey,
               let detailedManga = detailedManga
            {
                ReaderScreen(
                    plugin: plugin,
                    manga: detailedManga,
                    chaptersKey: selectedChapterKey,
                    chapter: selectedChapter
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(manga.title ?? manga.id)
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
        .apply {
            if UIDevice.isIPad {
                $0.toolbarBackground(.visible, for: .navigationBar)
            } else {
                $0
            }
        }
        .onAppear {
            loadDetailedManga()
        }
        .onReceive(plugin.objectWillChange) {
            loadDetailedManga()
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
                    print("Failed to load detailed manga: \(error)")
                }

                dismiss()
            }
        }
    }
}
