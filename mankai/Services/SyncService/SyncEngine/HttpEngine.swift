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

    func login(email: String, password: String) async throws {
        _email = email
        _password = password

        _refreshToken = nil
        _accessToken = nil

        try await getRefreshToken()
    }

    func logout() {
        _email = nil
        _password = nil
        _refreshToken = nil
        _accessToken = nil

        save()
    }

    private func getRefreshToken() async throws {
        guard let email = _email, let password = _password, let serverUrl = _serverUrl else {
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "missingCredentialsOrServerUrl"]
            )
        }

        guard let url = URL(string: serverUrl + "/auth/login") else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidServerUrl"]
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
            logout()
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidCredentials"]
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidJsonResponse"]
            )
        }

        guard let refreshToken = json["refreshToken"] as? String else {
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "noRefreshTokenInResponse"]
            )
        }

        _refreshToken = refreshToken
        save()
    }

    private func refreshAccessToken() async throws {
        guard let refreshToken = _refreshToken, let serverUrl = _serverUrl else {
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "missingRefreshTokenOrServerUrl"]
            )
        }

        guard let url = URL(string: serverUrl + "/auth/refresh") else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidServerUrl"]
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
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidResponse"]
            )
        }

        if httpResponse.statusCode == 401 {
            // maybe the refresh token is expired, try to get a new one
            try await getRefreshToken()
            return try await refreshAccessToken()
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "refreshFailed"]
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidJsonResponse"]
            )
        }

        guard let accessToken = json["accessToken"] as? String else {
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "noAccessTokenInResponse"]
            )
        }

        _accessToken = accessToken
        save()
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

    func get(path: String, query: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        return try await request(method: "GET", path: path, query: query, body: nil)
    }

    private func request(
        method: String, path: String, query: [String: String]? = nil, body: Data? = nil,
        retry: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        guard let serverUrl = _serverUrl else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "missingServerUrl"]
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
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidUrl"]
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
                try await refreshAccessToken()
                return try await request(method: method, path: path, query: query, body: body, retry: false)
            }

            if (200 ... 299).contains(httpResponse.statusCode) {
                return (data, httpResponse)
            } else {
                let errorMsg =
                    String(data: data, encoding: .utf8) ?? "HTTP error \(httpResponse.statusCode)"
                throw NSError(
                    domain: "HttpEngine", code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorMsg]
                )
            }
        } else {
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "invalidResponse"]
            )
        }
    }

    // MARK: - SyncEngine Overrides

    override func getSavedsHash() async throws -> String {
        let (data, _) = try await get(path: "/saveds/hash")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hash = json["hash"] as? String
        else {
            throw NSError(
                domain: "HttpEngine", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "invalidHashResponse"]
            )
        }
        return hash
    }

    override func getLatestSaved() async throws -> SavedModel? {
        let (data, _) = try await get(path: "/saveds", query: ["lm": "1"])
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let dict = arr.first else { return nil }

        guard let mangaId = dict["mangaId"] as? String,
              let pluginId = dict["pluginId"] as? String,
              let datetimeStr = dict["datetime"] as? String,
              let updates = dict["updates"] as? Bool,
              let latestChapter = dict["latestChapter"] as? String,
              let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
        else { return nil }

        return SavedModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, updates: updates, latestChapter: latestChapter)
    }

    override func saveSaveds(_ saveds: [SavedModel]) async throws {
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

    override func updateSaveds(_ saveds: [SavedModel]) async throws {
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

    override func getLatestRecord() async throws -> RecordModel? {
        let (data, _) = try await get(path: "/records", query: ["lm": "1"])
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]], let dict = arr.first else { return nil }

        guard let mangaId = dict["mangaId"] as? String,
              let pluginId = dict["pluginId"] as? String,
              let datetimeStr = dict["datetime"] as? String,
              let page = dict["page"] as? Int,
              let datetime = HttpEngine.iso8601Formatter.date(from: datetimeStr)
        else { return nil }
        let chapterId = dict["chapterId"] as? String
        let chapterTitle = dict["chapterTitle"] as? String

        return RecordModel(mangaId: mangaId, pluginId: pluginId, datetime: datetime, chapterId: chapterId, chapterTitle: chapterTitle, page: page)
    }

    override func updateRecords(_ records: [RecordModel]) async throws {
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

    override func getSaveds(_ since: Date? = nil) async throws -> [SavedModel] {
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
                else { return nil }
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

    override func getRecords(_ since: Date? = nil) async throws -> [RecordModel] {
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
                else { return nil }
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
