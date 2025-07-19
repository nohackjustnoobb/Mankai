//
//  SavedService.swift
//  mankai
//
//  Created by Travis XU on 17/7/2025.
//

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

    func update(saved: SavedModel, manga: MangaModel) -> Bool? {
        let result = try? DbService.shared.appDb?.write { db in
            try manga.upsert(db)
            try saved.upsert(db)

            return true
        }

        objectWillChange.send()
        return result
    }

    func delete(mangaId: String, pluginId: String) -> Bool? {
        let result = try? DbService.shared.appDb?.write { db in
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

        objectWillChange.send()
        return result
    }

    func getAll() -> [SavedModel] {
        let result = try? DbService.shared.appDb?.read { db in
            let request = SavedModel.order(Column("datetime").desc)

            return try request.fetchAll(db)
        }

        return result ?? []
    }
}
