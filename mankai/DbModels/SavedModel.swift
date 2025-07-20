//
//  SavedModel.swift
//  mankai
//
//  Created by Travis XU on 19/7/2025.
//

import Foundation
import GRDB

struct SavedModel {
    var mangaId: String
    var pluginId: String
    var datetime: Date
    var updates: Bool

    static func createTable(_ db: Database) throws {
        try db.create(table: SavedModel.databaseTableName, ifNotExists: true) {
            $0.primaryKey(["mangaId", "pluginId"])

            $0.column("mangaId", .text).notNull()
            $0.column("pluginId", .text).notNull()
            $0.column("datetime", .datetime).notNull()
            $0.column("updates", .boolean).notNull()

            $0.foreignKey(["mangaId", "pluginId"], references: MangaModel.databaseTableName, onDelete: .cascade)
        }
    }
}

extension SavedModel: TableRecord {
    static let databaseTableName = "saved"

    static let manga = belongsTo(MangaModel.self)
}

extension SavedModel: Codable, FetchableRecord, PersistableRecord {
    var manga: QueryInterfaceRequest<MangaModel> {
        request(for: SavedModel.manga)
    }
}
