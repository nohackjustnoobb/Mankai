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

    private init() {
        Logger.dbService.debug("Initializing DbService")
    }

    lazy var appDb: DatabasePool? = {
        Logger.dbService.debug("Initializing appDb")
        guard
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first
        else {
            Logger.dbService.error("Could not find document directory")
            return nil
        }
        let fullUrl = documentsURL.appendingPathComponent("db.sqlite3")
        Logger.dbService.info("Database path: \(fullUrl.path())")

        do {
            var config = Configuration()
            config.busyMode = .timeout(5.0)
            let dbPool = try DatabasePool(path: fullUrl.path(), configuration: config)

            try dbPool.write { db in
                try MangaModel.createTable(db)
                try SavedModel.createTable(db)
                try RecordModel.createTable(db)
                try JsPluginModel.createTable(db)
            }
            Logger.dbService.info("appDb initialized successfully")
            return dbPool
        } catch {
            Logger.dbService.error("Failed to initialize appDb", error: error)
            return nil
        }
    }()

    private var fsDb: [String: DatabasePool] = [:]

    func openFsDb(_ path: String, readOnly: Bool) -> DatabasePool? {
        Logger.dbService.debug("Opening FsDb at \(path), readOnly: \(readOnly)")
        var config = Configuration()
        config.readonly = readOnly
        config.busyMode = .timeout(5.0)

        do {
            let pool = try DatabasePool(path: path, configuration: config)

            try pool.write { db in
                try FsMangaModel.createTable(db)
                try FsChapterGroupModel.createTable(db)
                try FsChapterModel.createTable(db)
                try FsImageModel.createTable(db)
            }

            fsDb[path] = pool
            Logger.dbService.info("FsDb opened successfully at \(path)")
            return pool
        } catch {
            Logger.dbService.error("Failed to open FsDb at \(path)", error: error)
            return nil
        }
    }

    func getFsDb(_ path: String) -> DatabasePool? {
        return fsDb[path]
    }
}
