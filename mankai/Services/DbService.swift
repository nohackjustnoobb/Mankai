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

    private var fsDb: [String: DatabasePool] = [:]

    func openFsDb(_ path: String, readOnly: Bool) -> DatabasePool? {
        var config = Configuration()
        config.readonly = readOnly

        let pool = try? DatabasePool(path: path, configuration: config)

        try? pool?.write { db in
            try FsMangaModel.createTable(db)
            try FsChapterGroupModel.createTable(db)
            try FsChapterModel.createTable(db)
            try FsImageModel.createTable(db)
        }

        fsDb[path] = pool

        return pool
    }

    func getFsDb(_ path: String) -> DatabasePool? {
        return fsDb[path]
    }
}
