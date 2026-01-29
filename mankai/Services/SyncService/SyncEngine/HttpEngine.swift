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

    override private init() {
        Logger.httpEngine.debug("HttpEngine initialized")
        let defaults = UserDefaults.standard

        _email = defaults.string(forKey: "HttpEngine.email")
        _password = defaults.string(forKey: "HttpEngine.password")
        _refreshToken = defaults.string(forKey: "HttpEngine.refreshToken")
        _accessToken = defaults.string(forKey: "HttpEngine.accessToken")
        _serverUrl = defaults.string(forKey: "HttpEngine.serverUrl")
    }

    private var _email: String?
    private var _password: String?

    private var _refreshToken: String?
    private var _accessToken: String?

    override var id: String {
        return "HttpEngine"
    }

    override var name: String {
        return String(localized: "httpEngine")
    }

    var email: String? {
        return _email
    }

    private var _serverUrl: String?
    var serverUrl: String? {
        get {
            return _serverUrl
        }
        set {
            _serverUrl = newValue
            save()
        }
    }

    override var active: Bool {
        return _serverUrl != nil && _email != nil && _password != nil
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws {
        Logger.httpEngine.info("HttpEngine logging in with email: \(email)")
        _email = email
        _password = password

        _refreshToken = nil
        _accessToken = nil

        try await getRefreshToken()
        Logger.httpEngine.info("HttpEngine login successful")

        try await SyncService.shared.onEngineChange()
    }

    func logout() {
        Logger.httpEngine.info("HttpEngine logging out")
        _email = nil
        _password = nil
        _refreshToken = nil
        _accessToken = nil

        save()
    }

    private func getRefreshToken() async throws {
        Logger.httpEngine.debug("HttpEngine getting refresh token")
        guard let email = _email, let password = _password, let serverUrl = _serverUrl else {
            Logger.httpEngine.error("HttpEngine missing credentials or server URL")
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "missingCredentialsOrServerUrl")]
            )
        }

        guard let url = URL(string: serverUrl + "/auth/login") else {
            Logger.httpEngine.error("HttpEngine invalid server URL: \(serverUrl)")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidServerUrl")]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "email": email,
            "password": password,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            Logger.httpEngine.error("HttpEngine login failed with status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            logout()
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidCredentials")]
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            Logger.httpEngine.error("HttpEngine invalid JSON response during login")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidJsonResponse")]
            )
        }

        guard let refreshToken = json["refreshToken"] as? String else {
            Logger.httpEngine.error("HttpEngine no refresh token in response")
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "noRefreshTokenInResponse")]
            )
        }

        _refreshToken = refreshToken
        save()
        Logger.httpEngine.debug("HttpEngine refresh token obtained")
    }

    private func refreshAccessToken() async throws {
        Logger.httpEngine.debug("HttpEngine refreshing access token")
        guard let refreshToken = _refreshToken, let serverUrl = _serverUrl else {
            Logger.httpEngine.error("HttpEngine missing refresh token or server URL")
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "missingRefreshTokenOrServerUrl")]
            )
        }

        guard let url = URL(string: serverUrl + "/auth/refresh") else {
            Logger.httpEngine.error("HttpEngine invalid server URL: \(serverUrl)")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidServerUrl")]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "refreshToken": refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.httpEngine.error("HttpEngine invalid response during token refresh")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidResponse")]
            )
        }

        if httpResponse.statusCode == 401 {
            // maybe the refresh token is expired, try to get a new one
            Logger.httpEngine.warning("HttpEngine refresh token expired, trying to re-login")
            try await getRefreshToken()
            return try await refreshAccessToken()
        }

        guard httpResponse.statusCode == 200 else {
            Logger.httpEngine.error("HttpEngine refresh failed with status code: \(httpResponse.statusCode)")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "refreshFailed")]
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            Logger.httpEngine.error("HttpEngine invalid JSON response during token refresh")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidJsonResponse")]
            )
        }

        guard let accessToken = json["accessToken"] as? String else {
            Logger.httpEngine.error("HttpEngine no access token in response")
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "noAccessTokenInResponse")]
            )
        }

        _accessToken = accessToken
        save()
        Logger.httpEngine.debug("HttpEngine access token refreshed")
    }

    private func save() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        let defaults = UserDefaults.standard

        defaults.set(_email, forKey: "HttpEngine.email")
        defaults.set(_password, forKey: "HttpEngine.password")
        defaults.set(_refreshToken, forKey: "HttpEngine.refreshToken")
        defaults.set(_accessToken, forKey: "HttpEngine.accessToken")
        defaults.set(_serverUrl, forKey: "HttpEngine.serverUrl")
    }

    // MARK: - High-level HTTP Methods

    private func get(path: String, query: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        return try await request(method: "GET", path: path, query: query, body: nil)
    }

    private func request(
        method: String, path: String, query: [String: String]? = nil, body: Data? = nil,
        retry: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        Logger.httpEngine.debug("HttpEngine request: \(method) \(path)")
        guard let serverUrl = _serverUrl else {
            Logger.httpEngine.error("HttpEngine missing server URL")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "missingServerUrl")]
            )
        }

        var urlString = serverUrl + path

        if let query = query, !query.isEmpty {
            let queryString = query.map {
                "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            }.joined(separator: "&")
            urlString += "?" + queryString
        }

        guard let url = URL(string: urlString) else {
            Logger.httpEngine.error("HttpEngine invalid URL: \(urlString)")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidUrl")]
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken = _accessToken {
            urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            urlRequest.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401, retry {
                Logger.httpEngine.warning("HttpEngine request 401, retrying with token refresh")
                try await refreshAccessToken()
                return try await request(method: method, path: path, query: query, body: body, retry: false)
            }

            if (200 ... 299).contains(httpResponse.statusCode) {
                return (data, httpResponse)
            } else {
                let errorMsg =
                    String(data: data, encoding: .utf8) ?? "HTTP error \(httpResponse.statusCode)"
                Logger.httpEngine.error("HttpEngine request failed: \(errorMsg)")
                throw NSError(
                    domain: "HttpEngine", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )
            }
        } else {
            Logger.httpEngine.error("HttpEngine invalid response type")
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidResponse")]
            )
        }
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
        _ = try await request(method: "PUT", path: "/saveds", body: bodyData)
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
        let (data, _) = try await get(path: "/saveds/hash")
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
        let (data, _) = try await get(path: "/saveds", query: ["lm": "1"])
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
        _ = try await request(method: "POST", path: "/saveds", body: bodyData)
    }

    private func getLatestRecord() async throws -> RecordModel? {
        Logger.httpEngine.debug("HttpEngine getting latest record")
        let (data, _) = try await get(path: "/records", query: ["lm": "1"])
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
        _ = try await request(method: "POST", path: "/records", body: bodyData)
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

            let (data, _) = try await get(path: "/saveds", query: query)
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

            let (data, _) = try await get(path: "/records", query: query)
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
