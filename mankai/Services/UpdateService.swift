//
//  UpdateService.swift
//  mankai
//
//  Created by Travis XU on 20/7/2025.
//

import Foundation

class UpdateService: ObservableObject {
    static let shared = UpdateService()

    private init() {}

    var lastUpdateTime: Date? {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "UpdateService.lastUpdateTime") as? Date
    }

    func update() async throws {
        // Check if sync is needed (only if sync engine is configured)
        if SyncService.shared.engine != nil {
            if let lastSyncTime = SyncService.shared.lastSyncTime {
                // Check if last sync was more than 1 minute ago
                let timeInterval = Date().timeIntervalSince(lastSyncTime)
                if timeInterval > 60 { // 1 minute in seconds
                    try await SyncService.shared.sync()
                }
            } else {
                // No sync has been performed yet
                try await SyncService.shared.sync()
            }
        }

        // Get all saved mangas
        let saveds = SavedService.shared.getAll()

        // Group saveds by pluginId
        var savedsByPlugin: [String: [SavedModel]] = [:]
        for saved in saveds {
            if savedsByPlugin[saved.pluginId] == nil {
                savedsByPlugin[saved.pluginId] = []
            }
            savedsByPlugin[saved.pluginId]!.append(saved)
        }

        // Process each plugin's saved mangas
        var updatedSaveds: [SavedModel] = []
        var updatedMangaModels: [MangaModel] = []

        for (pluginId, pluginSaveds) in savedsByPlugin {
            // Get the plugin
            guard let plugin = PluginService.shared.getPlugin(pluginId) else {
                continue // Skip if plugin doesn't exist
            }

            // Get manga IDs for this plugin
            let mangaIds = pluginSaveds.map { $0.mangaId }

            // Fetch updated manga data from the plugin
            do {
                let updatedMangas = try await plugin.getMangas(mangaIds)

                // Create a dictionary for quick lookup
                var mangaDict: [String: Manga] = [:]
                for manga in updatedMangas {
                    mangaDict[manga.id] = manga
                }

                // Check for updates
                for saved in pluginSaveds {
                    guard let updatedManga = mangaDict[saved.mangaId] else {
                        continue // Skip if manga not found in updated data
                    }

                    // Check if there's a new chapter
                    var hasUpdate = false

                    if let newChapter = updatedManga.latestChapter {
                        let oldChapter = Chapter.decode(saved.latestChapter)

                        // Compare by id first, then by title
                        if let newId = newChapter.id, let oldId = oldChapter.id {
                            hasUpdate = newId != oldId
                        } else if let newTitle = newChapter.title, let oldTitle = oldChapter.title {
                            hasUpdate = newTitle != oldTitle
                        }
                        // If no id or title, ignore this manga

                        if hasUpdate {
                            // Create updated saved model
                            var updatedSaved = saved
                            updatedSaved.latestChapter = newChapter.encode()
                            updatedSaved.datetime = Date()
                            updatedSaved.updates = true
                            updatedSaveds.append(updatedSaved)
                        }
                    }

                    // Update manga model in database
                    if let mangaInfoData = try? JSONEncoder().encode(updatedManga),
                       let mangaInfoString = String(data: mangaInfoData, encoding: .utf8)
                    {
                        let mangaModel = MangaModel(
                            mangaId: updatedManga.id,
                            pluginId: pluginId,
                            info: mangaInfoString
                        )
                        updatedMangaModels.append(mangaModel)
                    }
                }
            } catch {
                // Skip this plugin if there's an error
                continue
            }
        }

        // Batch update all changed saveds and mangas
        if !updatedSaveds.isEmpty {
            _ = SavedService.shared.batchUpdate(saveds: updatedSaveds, mangas: updatedMangaModels)
        }

        // Update last update time
        UserDefaults.standard.set(Date(), forKey: "UpdateService.lastUpdateTime")

        await MainActor.run {
            self.objectWillChange.send()
        }
    }
}
