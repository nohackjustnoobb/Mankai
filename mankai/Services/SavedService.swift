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

    private init() {}

    func get(mangaId: String, pluginId: String) -> SavedModel? {
        let result = try? DbService.shared.appDb?.read { db in
            try SavedModel
                .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                .fetchOne(db)
        }

        return result
    }

    func add(saved: SavedModel, manga: MangaModel? = nil) async -> Bool? {
        let result = await update(saved: saved, manga: manga)

        if let result = result, result {
            Task {
                try await SyncService.shared.pushSaveds()
            }
        }

        return result
    }

    func remove(mangaId: String, pluginId: String) async -> Bool? {
        let result = await delete(mangaId: mangaId, pluginId: pluginId)

        if let result = result, result {
            Task {
                try await SyncService.shared.pushSaveds()
            }
        }

        return result
    }

    func update(saved: SavedModel, manga: MangaModel? = nil) async -> Bool? {
        let result = try? await DbService.shared.appDb?.write { db in
            if let manga = manga {
                try manga.upsert(db)
            }
            try saved.upsert(db)

            return true
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    func batchUpdate(saveds: [SavedModel], mangas: [MangaModel]? = nil) async -> Bool? {
        let result = try! await DbService.shared.appDb?.write { db in
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

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    func delete(mangaId: String, pluginId: String) async -> Bool? {
        let result = try? await DbService.shared.appDb?.write { db in
            let deleted =
                try SavedModel
                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                    .deleteAll(db)

            let recordExists =
                try RecordModel
                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                    .fetchCount(db) > 0

            if !recordExists {
                try MangaModel
                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                    .deleteAll(db)
            }

            return deleted > 0
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    func getAll() -> [SavedModel] {
        let result = try? DbService.shared.appDb?.read { db in
            let request = SavedModel.order(Column("datetime").desc)

            return try request.fetchAll(db)
        }

        return result ?? []
    }

    func getAllSince(date: Date) -> [SavedModel] {
        let result = try? DbService.shared.appDb?.read { db in
            try SavedModel
                .filter(Column("datetime") > date)
                .order(Column("datetime").asc)
                .fetchAll(db)
        }

        return result ?? []
    }

    func getLatest() -> SavedModel? {
        let result = try? DbService.shared.appDb?.read { db in
            try SavedModel
                .order(Column("datetime").desc)
                .limit(1)
                .fetchOne(db)
        }

        return result
    }

    func generateHash() -> String? {
        let result = try? DbService.shared.appDb?.read { db in
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
    }
}
