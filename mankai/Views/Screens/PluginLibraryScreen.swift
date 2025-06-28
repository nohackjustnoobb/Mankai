//
//  PluginLibraryScreen.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

struct PluginLibraryScreen: View {
    let plugin: Plugin

    @State private var selectedGenre: Genre = .all
    @State private var selectedStatus: Status = .any
    @State private var showingFilters = false

    @State private var tempSelectedGenre: Genre = .all
    @State private var tempSelectedStatus: Status = .any

    @State private var isLoading: Bool = false
    @State private var mangasList: [String: [UInt: [Manga]]] = [:]

    private var hasActiveFilters: Bool {
        selectedGenre != .all || selectedStatus != .any
    }

    private var allMangas: [Manga] {
        let key = "\(selectedGenre.rawValue)_\(selectedStatus.rawValue)"

        guard let mangas = mangasList[key] else {
            return []
        }

        let sortedKeys = mangas.keys.sorted()
        return sortedKeys.flatMap { mangas[$0] ?? [] }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            if selectedGenre != .all {
                                Button(action: {
                                    setGenre(.all)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(LocalizedStringKey(selectedGenre.rawValue))
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .genreTagStyle()
                                }
                            }

                            if selectedStatus != .any {
                                Button(action: {
                                    setStatus(.any)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(LocalizedStringKey(statusText(selectedStatus)))
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                    }
                                    .genreTagStyle()
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }

                if allMangas.isEmpty && !isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVStack {
                        MangasListView(mangas: allMangas, plugin: plugin)
                            .id("mangasList")

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        }

                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                loadList()
                            }
                    }
                    .padding()
                }
            }
            .clipped()
            .onChange(of: selectedGenre) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("mangasList", anchor: .top)
                }
            }
            .onChange(of: selectedStatus) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("mangasList", anchor: .top)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilters) {
            NavigationView {
                List {
                    Section {
                        Picker("genre", selection: $tempSelectedGenre) {
                            Text(LocalizedStringKey(Genre.all.rawValue))
                                .tag(Genre.all)

                            ForEach(plugin.availableGenres, id: \.self) { genre in
                                Text(LocalizedStringKey(genre.rawValue))
                                    .tag(genre)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("status", selection: $tempSelectedStatus) {
                            Text(statusText(.any)).tag(Status.any)
                            Text(statusText(.onGoing)).tag(Status.onGoing)
                            Text(statusText(.ended)).tag(Status.ended)
                        }
                        .pickerStyle(.menu)
                    } header: {
                        Spacer(minLength: 0)
                    }
                }
                .navigationTitle("filters")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: {
                            tempSelectedGenre = selectedGenre
                            tempSelectedStatus = selectedStatus
                            showingFilters = false
                        }) {
                            Text("cancel")
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: {
                            setFilters(genre: tempSelectedGenre, status: tempSelectedStatus)
                            showingFilters = false
                        }) {
                            Text("done")
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .onAppear {
                tempSelectedGenre = selectedGenre
                tempSelectedStatus = selectedStatus
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text(plugin.name ?? plugin.id)
                        .font(.headline)
                    Text("library")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showingFilters = true
                }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .onAppear {
            loadList()
        }
    }

    private func loadList() {
        if isLoading {
            return
        }

        let key = "\(selectedGenre.rawValue)_\(selectedStatus.rawValue)"

        let maxPage = mangasList[key]?.keys.max() ?? 0

        // reach the end of the list
        if mangasList[key]?[maxPage]?.count == 0 {
            return
        }

        let page = maxPage + 1

        isLoading = true
        Task {
            do {
                let result = try await plugin.getList(
                    page: page, genre: selectedGenre, status: selectedStatus)

                if mangasList[key] == nil {
                    mangasList[key] = [:]
                }

                mangasList[key]![page] = result

                isLoading = false
            } catch {
                // TODO: show an alert
                isLoading = false
                print("GetList failed: \(error)")
            }
        }
    }

    private func setGenre(_ genre: Genre) {
        guard genre != selectedGenre else { return }

        selectedGenre = genre
        loadList()
    }

    private func setStatus(_ status: Status) {
        guard status != selectedStatus else { return }

        selectedStatus = status
        loadList()
    }

    private func setFilters(genre: Genre, status: Status) {
        if selectedGenre != genre {
            selectedGenre = genre
        }

        if selectedStatus != status {
            selectedStatus = status
        }

        loadList()
    }
}
