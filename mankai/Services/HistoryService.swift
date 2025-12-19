//
//  HistoryService.swift
//  mankai
//
//  Created by Travis XU on 17/7/2025.
//

import Foundation
import GRDB

class HistoryService: ObservableObject {
    static let shared = HistoryService()

    private init() {}

    func get(mangaId: String, pluginId: String) -> RecordModel? {
        let result = try? DbService.shared.appDb?.read { db in
            try RecordModel
                .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
                .fetchOne(db)
        }

        return result
    }

    func add(record: RecordModel, manga: MangaModel? = nil) async -> Bool? {
        let result = await update(record: record, manga: manga)

        try? await DbService.shared.appDb?.write { db in
            // Set updates to false in the corresponding saved if it exists
            if var saved = try SavedModel
                .filter(Column("mangaId") == record.mangaId && Column("pluginId") == record.pluginId && Column("updates") == true)
                .fetchOne(db)
            {
                saved.updates = false
                saved.datetime = Date()
                try saved.update(db)
            }
        }

        return result
    }

    func update(record: RecordModel, manga: MangaModel? = nil) async -> Bool? {
        let result = try? await DbService.shared.appDb?.write { db in
            if let manga = manga {
                try manga.upsert(db)
            }
            try record.upsert(db)

            return true
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    func batchUpdate(records: [RecordModel], mangas: [MangaModel]? = nil) async -> Bool? {
        let result = try? await DbService.shared.appDb?.write { db in
            if let mangas = mangas {
                for manga in mangas {
                    try manga.upsert(db)
                }
            }

            for record in records {
                try record.upsert(db)
            }

            return true
        }

        await MainActor.run {
            self.objectWillChange.send()
        }

        return result
    }

    func getAll(limit: Int? = nil, offset: Int = 0) -> [RecordModel] {
        let result = try? DbService.shared.appDb?.read { db in
            var request = RecordModel.order(Column("datetime").desc)

            if let limit = limit {
                request = request.limit(limit, offset: offset)
            }

            return try request.fetchAll(db)
        }

        return result ?? []
    }

    func getAllSince(date: Date) -> [RecordModel] {
        let result = try? DbService.shared.appDb?.read { db in
            let request = RecordModel
                .filter(Column("datetime") > date)
                .order(Column("datetime").desc)

            return try request.fetchAll(db)
        }

        return result ?? []
    }

    func getLatest() -> RecordModel? {
        let result = try? DbService.shared.appDb?.read { db in
            try RecordModel
                .order(Column("datetime").desc)
                .limit(1)
                .fetchOne(db)
        }

        return result
    }

    //    func delete(mangaId: String, pluginId: String) -> Bool? {
    //        let result = try? DbService.shared.appDb?.write { db in
    //            let deleted =
    //                try RecordModel
    //                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
    //                    .deleteAll(db)
    //
    //            let savedExists =
    //                try SavedModel
    //                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
    //                    .fetchCount(db) > 0
    //
    //            if !savedExists {
    //                try MangaModel
    //                    .filter(Column("mangaId") == mangaId && Column("pluginId") == pluginId)
    //                    .deleteAll(db)
    //            }
    //
    //            return deleted > 0
    //        }
    //
    //        objectWillChange.send()
    //        return result
    //    }
}
