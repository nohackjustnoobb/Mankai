//
//  HttpEngine.swift
//  mankai
//
//  Created by Travis XU on 4/8/2025.
//

import Foundation

class HttpEngine: SyncEngine {
    static let shared = HttpEngine()

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

        save()
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
            throw NSError(
                domain: "HttpEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "loginFailed"]
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

    func post(path: String, body: [String: Any]? = nil, query: [String: String]? = nil) async throws
        -> (Data, HTTPURLResponse)
    {
        let bodyData =
            body != nil ? try JSONSerialization.data(withJSONObject: body!, options: []) : nil
        return try await request(method: "POST", path: path, query: query, body: bodyData)
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

    override func getLatestSaved() throws -> SavedModel? {
        fatalError("Not Implemented")
    }

    override func getLatestRecord() throws -> RecordModel? {
        fatalError("Not Implemented")
    }

    override func saveSaveds(_: [SavedModel]) throws {
        fatalError("Not Implemented")
    }

    override func saveRecords(_: [RecordModel]) throws {
        fatalError("Not Implemented")
    }

    override func getSaveds(_: Date? = nil) throws -> [SavedModel] {
        fatalError("Not Implemented")
    }

    override func getRecords(_: Date? = nil) throws -> [RecordModel] {
        fatalError("Not Implemented")
    }
}
