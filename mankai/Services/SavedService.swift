//
//  SavedService.swift
//  mankai
//
//  Created by Travis XU on 17/7/2025.
//

import CryptoKit
import Foundation
import GRDB

class SavedService: ObservableObject {
    /// The shared singleton instance of SavedService.
    static let shared = SavedService()

    private init() {
        Logger.savedService.debug("Initializing SavedService")
    }

    /// Retrieves a saved manga record.
    /// - Parameters:
    ///   - mangaId: The ID of the manga.
    ///   - pluginId: The ID of the plugin providing the manga.
    /// - Returns: The `SavedModel` if found, otherwise `nil`.
    func get(mangaId: String, pluginId: String) -> SavedModel? {
        Logger.savedService.debug("Getting saved manga for mangaId: \(mangaId), pluginId: \(pluginId)")
        do {
            let result = try DbService.shared.appDb?.read { db in
                try SavedModel
                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                    .fetchOne(db)
            }
            return result
        } catch {
            Logger.savedService.error("Failed to get saved manga", error: error)
            return nil
        }
    }

    /// Adds a manga to the saved list and push to remote.
    /// - Parameters:
    ///   - saved: The `SavedModel` to add.
    ///   - manga: The optional `MangaModel` associated with the saved item.
    /// - Returns: `true` if successful, `nil` if an error occurred.
    func add(saved: SavedModel, manga: MangaModel? = nil) async -> Bool? {
        Logger.savedService.debug("Adding saved manga: \(saved.mangaId)")
        let result = await update(saved: saved, manga: manga)

        if let result = result, result, SyncService.shared.engine != nil {
            do {
                try await SyncService.shared.pushSaveds()
            } catch {
                Logger.savedService.error("Failed to push saveds after adding", error: error)
            }
        }

        return result
    }

    /// Removes a manga from the saved list and push to remote.
    /// - Parameters:
    ///   - mangaId: The ID of the manga to remove.
    ///   - pluginId: The ID of the plugin providing the manga.
    /// - Returns: `true` if successful, `nil` if an error occurred.
    func remove(mangaId: String, pluginId: String) async -> Bool? {
        Logger.savedService.debug("Removing saved manga: \(mangaId)")
        let result = await delete(mangaId: mangaId, pluginId: pluginId)

        if let result = result, result, SyncService.shared.engine != nil {
            do {
                try await SyncService.shared.pushSaveds()
            } catch {
                Logger.savedService.error("Failed to push saveds after removing", error: error)
            }
        }

        return result
    }

    /// Updates an existing saved manga record.
    /// - Parameters:
    ///   - saved: The `SavedModel` to update.
    ///   - manga: The optional `MangaModel` to update.
    /// - Returns: `true` if successful, `nil` if an error occurred.
    func update(saved: SavedModel, manga: MangaModel? = nil) async -> Bool? {
        Logger.savedService.debug("Updating saved manga: \(saved.mangaId)")
        var result: Bool?
        do {
            result = try await DbService.shared.appDb?.write { db in
                if let manga = manga {
                    try manga.upsert(db)
                }
                try saved.upsert(db)

                return true
            }
        } catch {
            Logger.savedService.error("Failed to update saved manga", error: error)
            result = nil
        }

        if result == nil {
            Logger.savedService.error("Failed to update saved manga")
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    /// Batch updates multiple saved manga records and manga models.
    /// - Parameters:
    ///   - saveds: The list of `SavedModel` objects to update.
    ///   - mangas: The optional list of `MangaModel` objects to update.
    /// - Returns: `true` if successful, `nil` if an error occurred.
    func batchUpdate(saveds: [SavedModel], mangas: [MangaModel]? = nil) async -> Bool? {
        Logger.savedService.debug("Batch updating \(saveds.count) saved mangas")
        var result: Bool?
        do {
            result = try await DbService.shared.appDb?.write { db in
                if let mangas = mangas {
                    for manga in mangas {
                        try manga.upsert(db)
                    }
                }

                for saved in saveds {
                    try saved.upsert(db)
                }

                return true
            }
        } catch {
            Logger.savedService.error("Failed to batch update saved mangas", error: error)
            result = nil
        }

        if result == nil {
            Logger.savedService.error("Failed to batch update saved mangas")
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    /// Deletes a saved manga record and its associated manga model.
    /// - Parameters:
    ///   - mangaId: The ID of the manga to delete.
    ///   - pluginId: The ID of the plugin providing the manga.
    /// - Returns: `true` if successful, `nil` if an error occurred.
    func delete(mangaId: String, pluginId: String) async -> Bool? {
        Logger.savedService.debug("Deleting saved manga: \(mangaId)")
        var result: Bool?
        do {
            result = try await DbService.shared.appDb?.write { db in
                let deleted =
                    try SavedModel
                        .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                        .deleteAll(db)

                try MangaModel
                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                    .deleteAll(db)

                return deleted > 0
            }
        } catch {
            Logger.savedService.error("Failed to delete saved manga", error: error)
            result = nil
        }

        if result == nil {
            Logger.savedService.error("Failed to delete saved manga")
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    /// Retrieves all saved manga records.
    /// - Returns: A list of `SavedModel` objects.
    func getAll() -> [SavedModel] {
        Logger.savedService.debug("Getting all saved mangas")
        do {
            let result = try DbService.shared.appDb?.read { db in
                let request = SavedModel.order(Column("datetime").desc)

                return try request.fetchAll(db)
            }
            return result ?? []
        } catch {
            Logger.savedService.error("Failed to get all saved mangas", error: error)
            return []
        }
    }

    /// Retrieves all saved manga records updated since a specific date.
    /// - Parameter date: The date to filter records by.
    /// - Returns: A list of `SavedModel` objects.
    func getAllSince(date: Date?) -> [SavedModel] {
        Logger.savedService.debug("Getting saved mangas since: \(String(describing: date))")
        do {
            let result = try DbService.shared.appDb?.read { db in
                if let date = date {
                    return try SavedModel
                        .filter(Column("datetime") > date)
                        .order(Column("datetime").asc)
                        .fetchAll(db)
                } else {
                    return try SavedModel
                        .order(Column("datetime").asc)
                        .fetchAll(db)
                }
            }
            return result ?? []
        } catch {
            Logger.savedService.error("Failed to get saved mangas since date", error: error)
            return []
        }
    }

    /// Retrieves the most recently updated saved manga record.
    /// - Returns: The latest `SavedModel` if found, otherwise `nil`.
    func getLatest() -> SavedModel? {
        Logger.savedService.debug("Getting latest saved manga")
        do {
            let result = try DbService.shared.appDb?.read { db in
                try SavedModel
                    .order(Column("datetime").desc)
                    .limit(1)
                    .fetchOne(db)
            }
            return result
        } catch {
            Logger.savedService.error("Failed to get latest saved manga", error: error)
            return nil
        }
    }

    /// Generates a hash string representing the current state of saved mangas.
    /// - Returns: A SHA256 hash string, or `nil` if generation fails.
    func generateHash() -> String? {
        Logger.savedService.debug("Generating hash for saved mangas")
        do {
            let result = try DbService.shared.appDb?.read { db in
                // Fetch all saved items, sorted by mangaId and pluginId
                let saveds = try SavedModel
                    .order(Column("mangaId").asc, Column("pluginId").asc)
                    .fetchAll(db)

                // Concatenate primary keys
                let keyString = saveds
                    .map { "\($0.mangaId)|\($0.pluginId)" }
                    .joined()

                // Generate SHA256 hash
                let data = Data(keyString.utf8)
                let hash = SHA256.hash(data: data)

                // Convert hash to hex string
                return hash.compactMap { String(format: "%02x", $0) }.joined()
            }
            return result
        } catch {
            Logger.savedService.error("Failed to generate hash for saved mangas", error: error)
            return nil
        }
    }
}
