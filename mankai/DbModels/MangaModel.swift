//
//  MangaModel.swift
//  mankai
//
//  Created by Travis XU on 19/7/2025.
//

import GRDB

struct MangaModel {
    var mangaId: String
    var pluginId: String
    var info: String

    static func createTable(_ db: Database) throws {
        try db.create(table: MangaModel.databaseTableName, ifNotExists: true) {
            $0.primaryKey(["mangaId", "pluginId"])

            $0.column("mangaId", .text).notNull()
            $0.column("pluginId", .text).notNull()
            $0.column("info", .text).notNull()
        }
    }
}

extension MangaModel: TableRecord {
    static let databaseTableName = "manga"

    static let record = hasOne(RecordModel.self)
    static let saved = hasOne(SavedModel.self)
}

extension MangaModel: Codable, FetchableRecord, PersistableRecord {
    var saved: QueryInterfaceRequest<SavedModel> {
        request(for: MangaModel.saved)
    }

    var record: QueryInterfaceRequest<RecordModel> {
        request(for: MangaModel.record)
    }
}
