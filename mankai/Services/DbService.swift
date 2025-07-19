//
//  DbService.swift
//  mankai
//
//  Created by Travis XU on 26/6/2025.
//

import CoreData
import Foundation
import GRDB

class DbService {
    static let shared = DbService()

    private init() {}

    lazy var appDb: DatabasePool? = {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fullUrl = documentsURL.appendingPathComponent("db.sqlite3")

        let dbPool = try? DatabasePool(path: fullUrl.path())

        try? dbPool?.write { db in
            try MangaModel.createTable(db)
            try SavedModel.createTable(db)
            try RecordModel.createTable(db)
            try JsPluginModel.createTable(db)
        }

        return dbPool
    }()
}
