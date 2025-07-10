//
//  UpdateMangaModal.swift
//  mankai
//
//  Created by Travis XU on 1/7/2025.
//

import PhotosUI
import SwiftUI

struct UpdateMangaModal: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var plugin: ReadWriteFsPlugin? = nil
    var manga: DetailedManga? = nil

    var body: some View {
        NavigationView {
            UpdateMangaContent(
                plugin: plugin, manga: manga,
                plugins: appState.pluginService.plugins.filter { $0 is ReadWriteFsPlugin }
                    as! [ReadWriteFsPlugin]
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("cancel")
                    }
                }
            }
        }
    }
}

struct UpdateMangaContent: View {
    let plugins: [ReadWriteFsPlugin]
    let isCreatingManga: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var plugin: String
    @State private var manga: DetailedManga

    @State private var showingAddAuthorAlert = false
    @State private var newAuthorName = ""
    @State private var showingAddChapterGroupAlert = false
    @State private var newChapterGroup = ""
    @State private var showingRemoveChapterGroupAlert = false
    @State private var chapterKeyToRemove = ""

    @State private var coverImageData: Data?
    @State private var isCoverChanged = false
    @State private var selectedPhoto: PhotosPickerItem?

    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    @State private var showingDeleteConfirmation = false

    init(
        plugin: ReadWriteFsPlugin? = nil, manga: DetailedManga? = nil, plugins: [ReadWriteFsPlugin]
    ) {
        self.plugins = plugins
        self.isCreatingManga = manga == nil

        self._plugin = State(initialValue: plugin?.id ?? AppDirPlugin.shared.id)
        self._manga = State(initialValue: manga ?? DetailedManga())
    }

    private var title: Binding<String> {
        Binding<String>(
            get: {
                manga.title ?? ""
            },
            set: {
                manga.title = $0
            }
        )
    }

    private var description: Binding<String> {
        Binding<String>(
            get: {
                manga.description ?? ""
            },
            set: {
                manga.description = $0
            }
        )
    }

    private var status: Binding<Status> {
        Binding<Status>(
            get: {
                manga.status ?? .onGoing
            },
            set: {
                manga.status = $0
            }
        )
    }

    private func loadCoverImage() {
        guard !isCreatingManga,
              let coverUrl = manga.cover,
              !coverUrl.isEmpty,
              let plugin = plugins.first(where: { $0.id == plugin })
        else {
            coverImageData = nil
            return
        }

        Task {
            do {
                let imageData = try await plugin.getImage(coverUrl)
                coverImageData = imageData
            } catch {
                coverImageData = nil
            }
        }
    }

    private func updateManga() async {
        isProcessing = true

        do {
            guard let selectedPlugin = plugins.first(where: { $0.id == plugin }) else {
                errorMessage = String(localized: "selectedPluginNotFound")
                showingErrorAlert = true
                isProcessing = false
                return
            }

            try await selectedPlugin.updateManga(manga)

            if isCoverChanged, let coverData = coverImageData {
                try await selectedPlugin.updateCover(mangaId: manga.id, image: coverData)
            }

            isProcessing = false
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            isProcessing = false
        }
    }

    private func deleteManga() async {
        isProcessing = true

        do {
            guard let selectedPlugin = plugins.first(where: { $0.id == plugin }) else {
                errorMessage = String(localized: "selectedPluginNotFound")
                showingErrorAlert = true
                isProcessing = false
                return
            }

            try await selectedPlugin.deleteManga(manga.id)
            isProcessing = false
            dismiss()

        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
            isProcessing = false
        }
    }

    var body: some View {
        List {
            if isCreatingManga {
                Section {
                    Picker("plugin", selection: $plugin) {
                        ForEach(plugins) { plugin in
                            Text(plugin.name ?? plugin.id)
                                .tag(plugin.id)
                        }
                    }

                } header: {
                    Spacer(minLength: 0)
                }
            }

            Section("cover") {
                VStack(alignment: .center, spacing: 0) {
                    Group {
                        if let coverImageData = coverImageData,
                           let uiImage = UIImage(data: coverImageData)
                        {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(maxWidth: .infinity)
                                .scaledToFill()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(3 / 4, contentMode: .fit)
                                .overlay {
                                    VStack {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.title)
                                            .foregroundStyle(.secondary)
                                        Text("noCover")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                        }
                    }
                    .padding(.top)
                    .padding(.horizontal, 12)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(
                                systemName: "photo.badge.plus")
                            Text(coverImageData != nil ? "changeCover" : "addCover")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical)
                }
            }

            Section("info") {
                TextField("title", text: title)

                TextField("description", text: description, axis: .vertical)
                    .lineLimit(3 ... 6)

                Picker("status", selection: status) {
                    Text("onGoing")
                        .tag(Status.onGoing)
                    Text("ended")
                        .tag(Status.ended)
                }
            }

            Section("authors") {
                if !manga.authors.isEmpty {
                    ForEach(manga.authors, id: \.self) { author in
                        HStack {
                            Text(author)
                            Spacer()

                            Button(action: {
                                manga.authors.removeAll { $0 == author }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("remove") {
                                manga.authors.removeAll { $0 == author }
                            }
                            .tint(.red)
                        }
                    }
                }

                Button(action: {
                    showingAddAuthorAlert = true
                }) {
                    HStack {
                        Text("add")
                        Spacer()
                    }
                }
            }

            Section("genres") {
                if !manga.genres.isEmpty {
                    ForEach(manga.genres, id: \.self) { genre in
                        HStack {
                            Text(LocalizedStringKey(genre.rawValue))
                            Spacer()

                            Button(action: {
                                manga.genres.removeAll { $0 == genre }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("remove") {
                                manga.genres.removeAll { $0 == genre }
                            }
                            .tint(.red)
                        }
                    }
                }

                Menu {
                    ForEach(
                        Genre.allCases.filter { genre in
                            genre != .all && !manga.genres.contains(genre)
                        }, id: \.self
                    ) { genre in
                        Button(action: {
                            manga.genres.append(genre)
                        }) {
                            Text(LocalizedStringKey(genre.rawValue))
                        }
                    }
                } label: {
                    HStack {
                        Text("add")
                        Spacer()
                    }
                }
                .disabled(manga.genres.count >= Genre.allCases.count - 1)
            }

            Section("chapters") {
                if !manga.chapters.isEmpty {
                    ForEach(Array(manga.chapters.keys), id: \.self) { chapterKey in
                        HStack {
                            Text(LocalizedStringKey(chapterKey))
                            Spacer()

                            Button(action: {
                                chapterKeyToRemove = chapterKey
                                showingRemoveChapterGroupAlert = true
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button("remove") {
                                chapterKeyToRemove = chapterKey
                                showingRemoveChapterGroupAlert = true
                            }
                            .tint(.red)
                        }
                    }
                }

                Button(action: {
                    showingAddChapterGroupAlert = true
                }) {
                    HStack {
                        Text("add")
                        Spacer()
                    }
                }
            }

            if !isCreatingManga {
                Section {
                    Button(
                        "deleteManga",
                        role: .destructive,
                        action: {
                            showingDeleteConfirmation = true
                        }
                    )
                } header: {
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            loadCoverImage()
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            Task {
                if let newPhoto = newPhoto {
                    do {
                        if let data = try await newPhoto.loadTransferable(type: Data.self) {
                            coverImageData = data
                            isCoverChanged = true
                        }
                    } catch {
                        print("Failed to load photo: \(error)")
                    }
                }
            }
        }
        .alert("addAuthor", isPresented: $showingAddAuthorAlert) {
            TextField("authorName", text: $newAuthorName)

            Button("add") {
                let trimmedName = newAuthorName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty && !manga.authors.contains(trimmedName) {
                    manga.authors.append(trimmedName)
                }
                newAuthorName = ""
            }

            Button("cancel", role: .cancel) {
                newAuthorName = ""
            }
        } message: {
            Text("enterAuthorName")
        }
        .alert("addChapterGroup", isPresented: $showingAddChapterGroupAlert) {
            TextField("chapterGroup", text: $newChapterGroup)

            Button("add") {
                let trimmedKey = newChapterGroup.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedKey.isEmpty && !manga.chapters.keys.contains(trimmedKey) {
                    manga.chapters[trimmedKey] = []
                }
                newChapterGroup = ""
            }

            Button("cancel", role: .cancel) {
                newChapterGroup = ""
            }
        } message: {
            Text("enterChapterGroup")
        }
        .confirmationDialog(
            "removeChapterGroup", isPresented: $showingRemoveChapterGroupAlert,
            titleVisibility: .visible
        ) {
            Button("remove", role: .destructive) {
                manga.chapters.removeValue(forKey: chapterKeyToRemove)
                chapterKeyToRemove = ""
            }

            Button("cancel", role: .cancel) {
                chapterKeyToRemove = ""
            }
        } message: {
            Text("removeChapterGroupConfirmation")
        }
        .alert("error", isPresented: $showingErrorAlert) {
            Button("ok") {
                errorMessage = ""
            }
        } message: {
            Text(LocalizedStringKey(errorMessage))
        }
        .confirmationDialog(
            "deleteManga", isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("delete", role: .destructive) {
                Task {
                    await deleteManga()
                }
            }

            Button("cancel", role: .cancel) {}
        } message: {
            Text("deleteMangaConfirmation")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(isCreatingManga ? "createManga" : "editManga")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(
                    action: {
                        Task {
                            await updateManga()
                        }
                    }
                ) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text(isCreatingManga ? "create" : "done")
                    }
                }
                .disabled(isProcessing)
            }
        }
    }
}
