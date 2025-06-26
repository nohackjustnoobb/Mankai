//
//  JsPlugin.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import Foundation

enum ScriptType: String {
    case isOnline
    case getSuggestion
    case search
    case getList
    case getMangas
    case getDetailedManga
    case getChapter
    case getImage
}

class JsPlugin: Plugin {
    // ----------- Metadata -----------

    private var _id: String
    private var _name: String?
    private var _version: String?
    private var _description: String?
    private var _authors: [String]
    private var _repository: String?
    private var _updatesUrl: String?
    private var _availableGenres: [Genre]
    private var _configs: [Config]

    override var id: String { _id }
    override var name: String? { _name }
    override var version: String? { _version }
    override var description: String? { _description }
    override var authors: [String] { _authors }
    override var repository: String? { _repository }
    override var updatesUrl: String? { _updatesUrl }
    override var availableGenres: [Genre] { _availableGenres }
    override var configs: [Config] { _configs }

    // ----------- Methods Scripts -----------
    var _scripts: [ScriptType: String]
    var _funcName: [ScriptType: String] = [:]
    var _scriptsNoExport: [ScriptType: String] = [:]

    init(
        id: String, name: String? = nil, version: String? = nil, description: String? = nil,
        authors: [String] = [],
        repository: String? = nil,
        updatesUrl: String? = nil,
        availableGenres: [Genre] = [],
        scripts: [ScriptType: String] = [:],
        configs: [Config] = []
    ) {
        self._id = id
        self._name = name
        self._version = version
        self._description = description
        self._authors = authors
        self._repository = repository
        self._updatesUrl = updatesUrl
        self._availableGenres = availableGenres
        self._configs = configs

        self._scripts = scripts
        for (scriptType, script) in scripts {
            guard
                let regex = try? NSRegularExpression(
                    pattern: "export\\{(.*) as default\\};", options: []
                ),
                let match = regex.firstMatch(
                    in: script, options: [], range: NSRange(location: 0, length: script.utf16.count)
                ),
                let funcRange = Range(match.range(at: 1), in: script)
            else {
                fatalError("Invalid script format for \(scriptType.rawValue)")
            }

            let funcName = String(script[funcRange]).trimmingCharacters(
                in: .whitespacesAndNewlines)
            let cleanedScript = regex.stringByReplacingMatches(
                in: script, options: [],
                range: NSRange(location: 0, length: script.utf16.count), withTemplate: ""
            )

            _funcName[scriptType] = funcName
            _scriptsNoExport[scriptType] = cleanedScript
        }
    }

    private static func parseConfigArray(_ arr: [[String: Any]]) -> [Config] {
        arr.compactMap { dict in
            guard let key = dict["key"] as? String,
                  let name = dict["name"] as? String,
                  let type = dict["type"] as? String
            else {
                return nil
            }

            return Config(
                key: key,
                name: name,
                description: dict["description"] as? String,
                type: ConfigType(rawValue: type)!,
                defaultValue: dict["defaultValue"] as Any,
                option: dict["option"] as Any?
            )
        }
    }

    static func fromJson(_ json: [String: Any]) -> JsPlugin? {
        guard let id = json["id"] as? String else { return nil }
        let name = json["name"] as? String
        let version = json["version"] as? String
        let description = json["description"] as? String
        let authors = json["authors"] as? [String] ?? []
        let repository = json["repository"] as? String
        let updatesUrl = json["updatesUrl"] as? String
        let availableGenres =
            (json["availableGenres"] as? [String])?.compactMap { Genre(rawValue: $0) } ?? []
        let scripts =
            (json["scripts"] as? [String: String])?.reduce(into: [ScriptType: String]()) {
                if let scriptType = ScriptType(rawValue: $1.0) {
                    $0[scriptType] = $1.1
                }
            } ?? [:]
        let configs = (json["configs"] as? [[String: Any]]).map { parseConfigArray($0) } ?? []

        return JsPlugin(
            id: id, name: name, version: version, description: description, authors: authors,
            repository: repository, updatesUrl: updatesUrl, availableGenres: availableGenres,
            scripts: scripts, configs: configs
        )
    }

    // TODO: not tested
    static func fromUrl(_ url: URL) async -> JsPlugin? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            return nil
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        else {
            return nil
        }

        return fromJson(json)
    }

    // ----------- Methods -----------

    override func isOnline() async throws -> Bool {
        if _scripts[.isOnline] == nil {
            fatalError("Script for isOnline is not defined")
        }

        let script = "\(_scriptsNoExport[.isOnline]!) return await \(_funcName[.isOnline]!)();"
        print(script)
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let isOnline = result as? Bool else {
            throw NSError(
                domain: "JsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for isOnline"]
            )
        }

        return isOnline
    }

    override func getSuggestions(_ query: String) async throws -> [String] {
        if _scripts[.getSuggestion] == nil {
            fatalError("Script for getSuggestion is not defined")
        }

        let script =
            "\(_scriptsNoExport[.getSuggestion]!) return await \(_funcName[.getSuggestion]!)(\"\(query)\");"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let suggestions = result as? [String] else {
            throw NSError(
                domain: "JsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for suggestions"]
            )
        }

        return suggestions
    }

    override func search(_ query: String, page: UInt) async throws -> [Manga] {
        if _scripts[.search] == nil {
            fatalError("Script for search is not defined")
        }

        let script =
            "\(_scriptsNoExport[.search]!) return await \(_funcName[.search]!)(\"\(query)\",\(page));"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let mangas = result as? [Any] else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for mangas"]
            )
        }

        return mangas.compactMap { Manga(from: $0) }
    }

    override func getList(page: UInt, genre: Genre, status: Status) async throws -> [Manga] {
        if _scripts[.getList] == nil {
            fatalError("Script for getList is not defined")
        }

        let script =
            "\(_scriptsNoExport[.getList]!) return await \(_funcName[.getList]!)(\(page),\"\(genre.rawValue)\",\(status.rawValue));"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let mangas = result as? [Any] else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for mangas"]
            )
        }

        return mangas.compactMap { Manga(from: $0) }
    }

    override func getMangas(_ ids: [String]) async throws -> [Manga] {
        if _scripts[.getMangas] == nil {
            fatalError("Script for getMangas is not defined")
        }

        let idsJson = try JSONSerialization.data(withJSONObject: ids, options: [])
        let idsString = String(data: idsJson, encoding: .utf8) ?? "[]"

        let script =
            "\(_scriptsNoExport[.getMangas]!) return await \(_funcName[.getMangas]!)(\(idsString));"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let mangas = result as? [Any] else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for mangas"]
            )
        }

        return mangas.compactMap { Manga(from: $0) }
    }

    override func getDetailedManga(_ id: String) async throws -> DetailedManga {
        if _scripts[.getDetailedManga] == nil {
            fatalError("Script for getDetailedManga is not defined")
        }

        let script =
            "\(_scriptsNoExport[.getDetailedManga]!) return await \(_funcName[.getDetailedManga]!)(\"\(id)\");"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let detailedManga = result as? [String: Any] else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for DetailedManga"]
            )
        }

        if let detailedManga = DetailedManga(from: detailedManga) {
            return detailedManga
        } else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for DetailedManga"]
            )
        }
    }

    override func getChapter(manga: DetailedManga, chapter: Chapter) async throws -> [String] {
        if _scripts[.getChapter] == nil {
            fatalError("Script for getChapter is not defined")
        }

        let mangaJson = try JSONEncoder().encode(manga)
        let chapterJson = try JSONEncoder().encode(chapter)

        guard let mangaString = String(data: mangaJson, encoding: .utf8),
              let chapterString = String(data: chapterJson, encoding: .utf8)
        else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid manga or chapter format"]
            )
        }

        let script =
            "\(_scriptsNoExport[.getChapter]!) return await \(_funcName[.getChapter]!)(\(mangaString),\(chapterString));"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let images = result as? [String] else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for images"]
            )
        }

        return images
    }

    override func getImage(_ url: String) async throws -> Data {
        if _scripts[.getImage] == nil {
            fatalError("Script for getImage is not defined")
        }

        let script =
            "\(_scriptsNoExport[.getImage]!) return await \(_funcName[.getImage]!)(\"\(url)\");"
        let result = try await JsRuntime.shared.execute(script, from: _id)

        guard let imageBase64Encoded = result as? String else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid result format for image"]
            )
        }

        guard let imageData = Data(base64Encoded: imageBase64Encoded) else {
            throw NSError(
                domain: "JsPlugin", code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid base64 string for image"]
            )
        }

        return imageData
    }
}
