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
    static let shared = SavedService()

    private init() {
        Logger.savedService.debug("Initializing SavedService")
    }

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

    func add(saved: SavedModel, manga: MangaModel? = nil) async -> Bool? {
        Logger.savedService.debug("Adding saved manga: \(saved.mangaId)")
        let result = await update(saved: saved, manga: manga)

        if let result = result, result {
            do {
                try await SyncService.shared.pushSaveds()
            } catch {
                Logger.savedService.error("Failed to push saveds after adding", error: error)
            }
        }

        return result
    }

    func remove(mangaId: String, pluginId: String) async -> Bool? {
        Logger.savedService.debug("Removing saved manga: \(mangaId)")
        let result = await delete(mangaId: mangaId, pluginId: pluginId)

        if let result = result, result {
            do {
                try await SyncService.shared.pushSaveds()
            } catch {
                Logger.savedService.error("Failed to push saveds after removing", error: error)
            }
        }

        return result
    }

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
