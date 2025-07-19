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

    func update(record: RecordModel, manga: MangaModel) -> Bool? {
        let result = try? DbService.shared.appDb?.write { db in
            try manga.upsert(db)
            try record.upsert(db)

            return true
        }

        objectWillChange.send()
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
