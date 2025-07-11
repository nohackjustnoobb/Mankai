//
//  UpdateChapterModal.swift
//  mankai
//
//  Created by Travis XU on 3/7/2025.
//

import PhotosUI
import SwiftUI

struct UpdateChapterModal: View {
    let plugin: ReadWriteFsPlugin
    let manga: DetailedManga
    let chapter: Chapter
    let onRename: ((String, String) -> Void)?

    @State var urls: [String]? = nil
    @State var images: [String: UIImage] = [:]
    @State private var showingTitleAlert = false
    @State private var newTitle = ""
    @State private var selectedItems: [PhotosPickerItem] = []

    private func loadUrls() {
        Task {
            do {
                urls = try await plugin.getChapter(manga: manga, chapter: chapter)
            } catch {
                // TODO: error handle
                print("Failed to load chapter: \(error)")
            }
        }
    }

    private func loadImages() {
        if let urls = urls {
            for url in urls {
                if images[url] != nil {
                    continue
                }

                Task {
                    do {
                        let data = try await plugin.getImage(url)
                        images[url] = UIImage(data: data)
                    } catch {
                        // TODO: error handle
                        print("Failed to load image: \(error)")
                    }
                }
            }
        }
    }

    private func moveImage(from source: IndexSet, to destination: Int) {
        guard let chapterId = chapter.id, let urls = urls else { return }
        var ids = urls.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        ids.move(fromOffsets: source, toOffset: destination)

        Task {
            do {
                try await plugin.arrangeImageOrder(
                    mangaId: manga.id, chapterId: chapterId, ids: ids
                )
                loadUrls()
            } catch {
                // TODO: error handle
                print("Failed to reorder images: \(error)")
            }
        }
    }

    private func deleteImage(at offsets: IndexSet) {
        guard let chapterId = chapter.id, let urls = urls else { return }
        let idsToRemove: [String] = offsets.map { idx in
            URL(fileURLWithPath: urls[idx]).deletingPathExtension().lastPathComponent
        }

        Task {
            do {
                try await plugin.removeImages(
                    mangaId: manga.id, chapterId: chapterId, ids: idsToRemove
                )
                loadUrls()
            } catch {
                // TODO: error handle
                print("Failed to load image: \(error)")
            }
        }
    }

    private func addSelectedImages() {
        guard let chapterId = chapter.id, !selectedItems.isEmpty else { return }

        Task {
            var newImages: [Data] = []

            for item in selectedItems {
                do {
                    if let data = try await item.loadTransferable(type: Data.self) {
                        newImages.append(data)
                    }
                } catch {
                    print("Failed to load selected image: \(error)")
                }
            }

            do {
                try await plugin.addImages(
                    mangaId: manga.id, chapterId: chapterId, images: newImages
                )

                loadUrls()
                selectedItems = []
            } catch {
                // TODO: error handle
                print("Failed to add new images: \(error)")
            }
        }
    }

    var body: some View {
        List {
            if let urls = urls {
                Section {
                    PhotosPicker(
                        selection: $selectedItems,
                        matching: .images
                    ) {
                        Text("add")
                            .padding(.horizontal, 20)
                    }
                    .onChange(of: selectedItems) {
                        if !selectedItems.isEmpty {
                            addSelectedImages()
                        }
                    }

                    ForEach(urls, id: \.self) { url in
                        Group {
                            if let image = images[url] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .padding()
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .onMove(perform: moveImage)
                    .onDelete(perform: deleteImage)
                } header: {
                    Text("editChaptersInstructions")
                        .font(.caption)
                        .textCase(.none)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom)
                }
                .listRowInsets(EdgeInsets())
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(chapter.title ?? chapter.id ?? "nil")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    newTitle = chapter.title ?? chapter.id ?? ""
                    showingTitleAlert = true
                }) {
                    VStack {
                        Text("editChapter")
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack(spacing: 4) {
                            Text(chapter.title ?? chapter.id ?? "nil")
                                .font(.caption)
                            Image(systemName: "pencil")
                                .font(.caption2)
                        }

                        .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert(Text("editChapterTitle"), isPresented: $showingTitleAlert) {
            TextField("chapterTitle", text: $newTitle)
            Button("cancel", role: .cancel) {}
            Button("save") {
                let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedTitle.isEmpty && trimmedTitle != chapter.title && chapter.id != nil {
                    onRename?(chapter.id!, trimmedTitle)
                }
            }
        } message: {
            Text("enterNewChapterTitle")
        }
        .onAppear {
            loadUrls()
        }
        .onChange(of: urls) {
            loadImages()
        }
    }
}
