//
//  UpdateChaptersModal.swift
//  mankai
//
//  Created by Travis XU on 3/7/2025.
//

import SwiftUI

struct UpdateChaptersModal: View {
    let plugin: ReadWriteFsPlugin
    let manga: DetailedManga
    let chaptersKey: String
    var isRootOfSheet: Bool

    @State private var chapters: [FsChapterModel] = []
    @State private var showingAddAlert = false
    @State private var newChapterName = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    @State private var chapterGroupId: Int? = nil

    @Environment(\.dismiss) private var dismiss

    init(
        plugin: ReadWriteFsPlugin, manga: DetailedManga, chaptersKey: String,
        isRootOfSheet: Bool = false
    ) {
        self.plugin = plugin
        self.manga = manga
        self.chaptersKey = chaptersKey
        self.isRootOfSheet = isRootOfSheet
    }

    private func fetchChapters() {
        guard let groupId = chapterGroupId else { return }
        Task {
            do {
                let fetchedChapters = try await plugin.getChapters(groupId: groupId)
                chapters = fetchedChapters
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }

    private func moveChapter(from source: IndexSet, to destination: Int) {
        chapters.move(fromOffsets: source, toOffset: destination)

        let currentChapters = chapters
        Task {
            do {
                let ids = currentChapters.compactMap { $0.id }
                try await plugin.arrangeChapterOrder(ids: ids)

                fetchChapters()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }

    private func deleteChapter(at offsets: IndexSet) {
        let chaptersToDelete = offsets.map { chapters[$0] }
        chapters.remove(atOffsets: offsets)

        Task {
            do {
                for chapter in chaptersToDelete {
                    if let id = chapter.id {
                        try await plugin.deleteChapter(id: id, mangaId: manga.id)
                    }
                }

                fetchChapters()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }

    private func renameChapter(for chapterId: Int, to newTitle: String) {
        guard let index = chapters.firstIndex(where: { $0.id == chapterId }) else { return }

        let sequence = chapters[index].sequence

        Task {
            do {
                guard let groupId = chapterGroupId else {
                    throw NSError(
                        domain: "UpdateChaptersModal", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: String(localized: "chapterGroupNotFound")]
                    )
                }

                try await plugin.upsertChapter(
                    id: chapterId, title: newTitle, sequence: sequence, chapterGroupId: groupId
                )

                fetchChapters()
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button("add") {
                        showingAddAlert = true
                    }
                    .padding(.horizontal, 20)

                    ForEach(chapters, id: \.id) { chapter in
                        NavigationLink(destination: {
                            UpdateChapterModal(
                                plugin: plugin,
                                manga: manga,
                                chapter: Chapter(id: String(chapter.id!), title: chapter.title),
                                onRename: { id, title in
                                    if let intId = Int(id) {
                                        renameChapter(for: intId, to: title)
                                    }
                                }
                            )
                        }) {
                            Text(chapter.title)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                    }
                    .onMove(perform: moveChapter)
                    .onDelete(perform: deleteChapter)
                } header: {
                    Text("editChaptersInstructions")
                        .font(.caption)
                        .textCase(.none)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom)
                }
                .listRowInsets(EdgeInsets())
            }
            .navigationBarTitleDisplayMode(.inline)
            .apply {
                if isRootOfSheet {
                    $0
                        .navigationTitle(LocalizedStringKey(chaptersKey))
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                VStack {
                                    Text("editChapters")
                                        .font(.headline)
                                    Text(LocalizedStringKey(chaptersKey))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ToolbarItem(placement: .confirmationAction) {
                                Button("close") {
                                    dismiss()
                                }
                            }
                        }
                } else {
                    $0
                }
            }
        }
        .alert("addChapter", isPresented: $showingAddAlert) {
            TextField("chapterTitle", text: $newChapterName)
            Button("add") {
                let trimmedName = newChapterName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    Task {
                        do {
                            guard let groupId = chapterGroupId else {
                                throw NSError(
                                    domain: "UpdateChaptersModal", code: 1,
                                    userInfo: [NSLocalizedDescriptionKey: "Chapter group not found"]
                                )
                            }

                            // Determine sequence based on max sequence
                            let maxSequence = chapters.map(\.sequence).max() ?? -1
                            let newSequence = maxSequence + 1

                            try await plugin.upsertChapter(
                                title: trimmedName, sequence: newSequence, chapterGroupId: groupId
                            )

                            fetchChapters()
                        } catch {
                            errorMessage = error.localizedDescription
                            showingErrorAlert = true
                        }
                    }
                }
                newChapterName = ""
            }
            Button("cancel", role: .cancel) {
                newChapterName = ""
            }
        } message: {
            Text("enterChapterTitle")
        }
        .alert("failedToEditChapters", isPresented: $showingErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(LocalizedStringKey(chaptersKey))
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("editChapters")
                        .font(.headline)
                    Text(LocalizedStringKey(chaptersKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            do {
                if let groupId = try await plugin.getChapterGroupId(mangaId: manga.id, title: chaptersKey) {
                    self.chapterGroupId = groupId
                    fetchChapters()
                } else {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}
