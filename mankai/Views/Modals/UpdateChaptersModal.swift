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

    @State private var chapters: [Chapter]
    @State private var showingAddAlert = false
    @State private var newChapterName = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""

    @Environment(\.dismiss) private var dismiss

    init(
        plugin: ReadWriteFsPlugin, manga: DetailedManga, chaptersKey: String,
        isRootOfSheet: Bool = false
    ) {
        self.plugin = plugin
        self.manga = manga
        self.chaptersKey = chaptersKey
        self.chapters = manga.chapters[chaptersKey] ?? []
        self.isRootOfSheet = isRootOfSheet
    }

    private func moveChapter(from source: IndexSet, to destination: Int) {
        chapters.move(fromOffsets: source, toOffset: destination)
        update()
    }

    private func deleteChapter(at offsets: IndexSet) {
        chapters.remove(atOffsets: offsets)
        update()
    }

    private func renameChapter(for chapterId: String, to newTitle: String) {
        chapters = chapters.map { chapter in
            if chapter.id == chapterId {
                return Chapter(id: chapterId, title: newTitle)
            }

            return chapter
        }

        update()
    }

    private func update() {
        guard var manga = Copy(of: manga) else {
            return
        }

        manga.chapters[chaptersKey] = chapters
        manga.latestChapter = chapters.last
        manga.updatedAt = Date()

        Task {
            do {
                try await plugin.updateManga(manga)
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
                                chapter: chapter,
                                onRename: renameChapter
                            )
                        }) {
                            Text(chapter.title ?? chapter.id ?? "nil")
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
                    let newChapter = Chapter(id: UUID().uuidString, title: trimmedName)
                    chapters.append(newChapter)
                    update()
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
    }
}
