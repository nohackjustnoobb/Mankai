//
//  HttpEngine.swift
//  mankai
//
//  Created by Travis XU on 4/8/2025.
//

import Foundation

class HttpEngine: SyncEngine {
    static let shared = HttpEngine()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private let authManager: AuthManager

    override private init() {
        authManager = AuthManager(id: "HttpEngine")
        super.init()

        authManager.postSave = { [weak self] in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }

        authManager.postLogin = {
            Task { try? await SyncService.shared.onEngineChange() }
        }

        Logger.httpEngine.debug("HttpEngine initialized")
    }

    override var id: String {
        return "HttpEngine"
    }

    override var name: String {
        return String(localized: "httpEngine")
    }

    var username: String? {
        return authManager.username
    }

    var serverUrl: String? {
        get {
            return authManager.serverUrl
        }
        set {
            authManager.serverUrl = newValue
        }
    }

    override var active: Bool {
        return authManager.loggedIn
    }

    // MARK: - Authentication

    func login(username: String, password: String) async throws {
        Logger.httpEngine.info("HttpEngine logging in with username: \(username)")
        try await authManager.login(username: username, password: password)
        Logger.httpEngine.info("HttpEngine login successful")
    }

    func logout() {
        Logger.httpEngine.info("HttpEngine logging out")
        authManager.logout()
    }

    // MARK: - SyncEngine Overrides

    override func onSelected() async throws {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "HttpEngine.lastSyncTime.records")
        defaults.removeObject(forKey: "HttpEngine.lastSyncTime.saveds")

        Logger.httpEngine.debug("HttpEngine selected handling")

        // Get hash from remote server
        let remoteHash = try await getSavedsHash()

        // Get local hash
        let localHash = SavedService.shared.generateHash()

        // Compare hashes
        if remoteHash != localHash {
            Logger.httpEngine.info("Hashes mismatch, syncing saveds")
            // Pull saveds from remote
            let remoteSaveds = try await getSaveds()

            // Fetch local saveds once for both filtering and pushing
            let localSaveds = SavedService.shared.getAll()

            // Add saveds from remote
            if !remoteSaveds.isEmpty {
                let localKeys = Set(localSaveds.map { "\($0.mangaId)|\($0.pluginId)" })

                let newRemoteSaveds = remoteSaveds.filter { saved in
                    let key = "\(saved.mangaId)|\(saved.pluginId)"
                    return !localKeys.contains(key)
                }

                if !newRemoteSaveds.isEmpty {
                    _ = await SavedService.shared.batchUpdate(saveds: newRemoteSaveds)
                }
            }

            // Push all local saveds to remote
            try await saveSaveds(localSaveds)
        } else {
            Logger.httpEngine.debug("Hashes match, skipping saveds sync")
        }

        // Call sync
        try await sync()
        try await UpdateService.shared.update()
    }

    override func sync() async throws {
        Logger.httpEngine.debug("Starting sync")

        let defaults = UserDefaults.standard

        // Sync Saveds
        try await syncSaveds(defaults: defaults)

        // Sync Records
        try await syncRecords(defaults: defaults)

        Logger.httpEngine.debug("Sync completed")
    }

    override func saveSaveds(_ saveds: [SavedModel]) async throws {
        Logger.httpEngine.debug("HttpEngine saving \(saveds.count) saveds")
        let bodyArr: [[String: Any]] = saveds.map { saved in
            [
                "mangaId": saved.mangaId,
                "pluginId": saved.pluginId,
                "datetime": Int(saved.datetime.timeIntervalSince1970 * 1000),
                "updates": saved.updates,
                "latestChapter": saved.latestChapter,
            ]
        }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyArr, options: [])
        _ = try await authManager.request(method: "PUT", path: "/saveds", body: bodyData)
    }

    // MARK: - Internal Sync Logic

    private func syncSaveds(defaults: UserDefaults) async throws {
        Logger.httpEngine.debug("Syncing saveds")
        // Get hash from remote server
        let remoteHash = try await getSavedsHash()

        // Get local hash
        let localHash = SavedService.shared.generateHash()

        // Compare hashes
        if remoteHash != localHash {
            Logger.httpEngine.info("Hashes mismatch, updating saveds")

            // Hashes don't match, pull all saveds from remote
            let remoteSaveds = try await getSaveds()

            // Get all local saveds
            let localSaveds = SavedService.shared.getAll()

            // Create sets for efficient lookup
            let remoteKeys = Set(remoteSaveds.map { "\($0.mangaId)|\($0.pluginId)" })

            // Delete saveds that exist locally but not in remote
            for saved in localSaveds {
                let key = "\(saved.mangaId)|\(saved.pluginId)"
                if !remoteKeys.contains(key) {
                    _ = await SavedService.shared.delete(mangaId: saved.mangaId, pluginId: saved.pluginId)
                }
            }

            // Add saveds from remote
            if !remoteSaveds.isEmpty {
                let localKeys = Set(localSaveds.map { "\($0.mangaId)|\($0.pluginId)" })
                let newRemoteSaveds = remoteSaveds.filter { saved in
                    let key = "\(saved.mangaId)|\(saved.pluginId)"
                    return !localKeys.contains(key)
                }

                if !newRemoteSaveds.isEmpty {
                    _ = await SavedService.shared.batchUpdate(saveds: newRemoteSaveds)
                }
            }
        }

        // Get latest saved from remote
        let remoteLatest = try await getLatestSaved()

        // Get latest saved from local
        let localLatest = SavedService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            Logger.httpEngine.debug("Saveds already synced")
            defaults.set(Date(), forKey: "HttpEngine.lastSyncTime.saveds")
            return
        }

        // Get last sync time for saveds
        let lastSyncTime = defaults.object(forKey: "HttpEngine.lastSyncTime.saveds") as? Date

        // Fetch and upload new local saveds since last sync
        let newLocalSaveds = SavedService.shared.getAllSince(date: lastSyncTime)
        if !newLocalSaveds.isEmpty {
            Logger.httpEngine.info("Uploading \(newLocalSaveds.count) new local saveds")
            try await updateSaveds(newLocalSaveds)
        }

        // Get remote saveds since last sync
        let remoteSavedsUpdates = try await getSaveds(lastSyncTime)

        // Update local database with remote saveds
        if !remoteSavedsUpdates.isEmpty {
            Logger.httpEngine.info("Downloading \(remoteSavedsUpdates.count) remote saveds updates")
            _ = await SavedService.shared.batchUpdate(saveds: remoteSavedsUpdates)
        }

        // Update last sync time for saveds
        defaults.set(Date(), forKey: "HttpEngine.lastSyncTime.saveds")
    }

    private func syncRecords(defaults: UserDefaults) async throws {
        Logger.httpEngine.debug("Syncing records")
        // Get latest record from remote
        let remoteLatest = try await getLatestRecord()

        // Get latest record from local
        let localLatest = HistoryService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            Logger.httpEngine.debug("Records already synced")
            defaults.set(Date(), forKey: "HttpEngine.lastSyncTime.records")
            return
        }

        // Get last sync time
        let lastSyncTime = defaults.object(forKey: "HttpEngine.lastSyncTime.records") as? Date

        // Fetch and upload new local data since last sync
        let newLocalRecords = HistoryService.shared.getAllSince(date: lastSyncTime)
        if !newLocalRecords.isEmpty {
            Logger.httpEngine.info("Uploading \(newLocalRecords.count) new local records")
            try await updateRecords(newLocalRecords)
        }

        // Get remote records since last sync
        let remoteRecords = try await getRecords(lastSyncTime)

        // Update local database with remote records
        if !remoteRecords.isEmpty {
            Logger.httpEngine.info("Downloading \(remoteRecords.count) remote records updates")
            _ = await HistoryService.shared.batchUpdate(records: remoteRecords)
        }

        // Update last sync time
        defaults.set(Date(), forKey: "HttpEngine.lastSyncTime.records")
    }

    private func getSavedsHash() async throws -> String {
        Logger.httpEngine.debug("HttpEngine getting saveds hash")
        let (data, _) = try await authManager.get(path: "/saveds/hash")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hash = json["hash"] as? String
        else {
            Logger.httpEngine.error("HttpEngine invalid hash response")
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidHashResponse")]
            )
        }
        return hash
    }

    private func getLatestSaved() async throws -> SavedModel? {
        Logger.httpEngine.debug("HttpEngine getting latest saved")
        let (data, _) = try await authManager.get(path: "/saveds", query: ["lm": "1"])
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let dict = arr.first else { return nil }

        guard let mangaId = dict["mangaId"] as? String,
              let pluginId = dict["pluginId"] as? String,
              let datetimeStr = dict["datetime"] as? String,
              let updates = dict["updates"] as? Bool,
              let latestChapter = dict["latestChapter"] as? String,
              let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
        else {
            Logger.httpEngine.error("HttpEngine failed to parse latest saved")
            return nil
        }

        return SavedModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, updates: updates, latestChapter: latestChapter)
    }

    private func updateSaveds(_ saveds: [SavedModel]) async throws {
        Logger.httpEngine.debug("HttpEngine updating \(saveds.count) saveds")
        let bodyArr: [[String: Any]] = saveds.map { saved in
            [
                "mangaId": saved.mangaId,
                "pluginId": saved.pluginId,
                "datetime": Int(saved.datetime.timeIntervalSince1970 * 1000),
                "updates": saved.updates,
                "latestChapter": saved.latestChapter,
            ]
        }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyArr, options: [])
        _ = try await authManager.request(method: "POST", path: "/saveds", body: bodyData)
    }

    private func getLatestRecord() async throws -> RecordModel? {
        Logger.httpEngine.debug("HttpEngine getting latest record")
        let (data, _) = try await authManager.get(path: "/records", query: ["lm": "1"])
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let dict = arr.first else { return nil }

        guard let mangaId = dict["mangaId"] as? String,
              let pluginId = dict["pluginId"] as? String,
              let datetimeStr = dict["datetime"] as? String,
              let page = dict["page"] as? Int,
              let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
        else {
            Logger.httpEngine.error("HttpEngine failed to parse latest record")
            return nil
        }
        let chapterId = dict["chapterId"] as? String
        let chapterTitle = dict["chapterTitle"] as? String

        return RecordModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, chapterId: chapterId, chapterTitle: chapterTitle, page: page)
    }

    private func updateRecords(_ records: [RecordModel]) async throws {
        Logger.httpEngine.debug("HttpEngine updating \(records.count) records")
        let bodyArr: [[String: Any]] = records.map { record in
            var dict: [String: Any] = [
                "mangaId": record.mangaId,
                "pluginId": record.pluginId,
                "datetime": Int(record.datetime.timeIntervalSince1970 * 1000),
                "page": record.page,
            ]
            if let chapterId = record.chapterId { dict["chapterId"] = chapterId }
            if let chapterTitle = record.chapterTitle { dict["chapterTitle"] = chapterTitle }
            return dict
        }
        let bodyData = try JSONSerialization.data(withJSONObject: bodyArr, options: [])
        _ = try await authManager.request(method: "POST", path: "/records", body: bodyData)
    }

    private func getSaveds(_ since: Date? = nil) async throws -> [SavedModel] {
        Logger.httpEngine.debug("HttpEngine getting saveds since: \(String(describing: since))")
        var allResults: [SavedModel] = []
        var offset = 0
        let limit = 50

        while true {
            var query: [String: String] = [
                "os": String(offset),
                "lm": String(limit),
            ]
            if let since = since {
                let ts = Int(since.timeIntervalSince1970 * 1000)
                query["ts"] = String(ts)
            }

            let (data, _) = try await authManager.get(path: "/saveds", query: query)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { break }

            let results = arr.compactMap { dict -> SavedModel? in
                guard let mangaId = dict["mangaId"] as? String,
                      let pluginId = dict["pluginId"] as? String,
                      let datetimeStr = dict["datetime"] as? String,
                      let updates = dict["updates"] as? Bool,
                      let latestChapter = dict["latestChapter"] as? String,
                      let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
                else {
                    Logger.httpEngine.error("HttpEngine failed to parse saved item")
                    return nil
                }
                return SavedModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, updates: updates, latestChapter: latestChapter)
            }

            allResults.append(contentsOf: results)

            if results.count < limit {
                break
            }

            offset += limit
        }

        return allResults
    }

    private func getRecords(_ since: Date? = nil) async throws -> [RecordModel] {
        Logger.httpEngine.debug("HttpEngine getting records since: \(String(describing: since))")
        var allResults: [RecordModel] = []
        var offset = 0
        let limit = 50

        while true {
            var query: [String: String] = [
                "os": String(offset),
                "lm": String(limit),
            ]
            if let since = since {
                let ts = Int(since.timeIntervalSince1970 * 1000)
                query["ts"] = String(ts)
            }

            let (data, _) = try await authManager.get(path: "/records", query: query)
            guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { break }

            let results = arr.compactMap { dict -> RecordModel? in
                guard let mangaId = dict["mangaId"] as? String,
                      let pluginId = dict["pluginId"] as? String,
                      let datetimeStr = dict["datetime"] as? String,
                      let page = dict["page"] as? Int,
                      let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
                else {
                    Logger.httpEngine.error("HttpEngine failed to parse record item")
                    return nil
                }
                let chapterId = dict["chapterId"] as? String
                let chapterTitle = dict["chapterTitle"] as? String
                return RecordModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, chapterId: chapterId, chapterTitle: chapterTitle, page: page)
            }

            allResults.append(contentsOf: results)

            if results.count < limit {
                break
            }

            offset += limit
        }

        return allResults
    }
}
