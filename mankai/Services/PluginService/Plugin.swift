//
//  Plugin.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import Foundation

enum ConfigType: String {
    case text
    case number
    case boolean
    case select
}

struct Config {
    var key: String
    var name: String
    var description: String?
    var type: ConfigType
    var defaultValue: Any
    var options: [Any]?
}

struct ConfigValue {
    var key: String
    var value: Any
}

class Plugin: Identifiable, ObservableObject {
    // MARK: - Metadata

    var id: String {
        fatalError("Not Implemented")
    }

    var name: String? {
        nil
    }

    var version: String? {
        nil
    }

    var tag: String? {
        nil
    }

    var description: String? {
        nil
    }

    var authors: [String] {
        []
    }

    var repository: String? {
        nil
    }

    var updatesUrl: String? {
        nil
    }

    var availableGenres: [Genre] {
        []
    }

    var configs: [Config] {
        []
    }

    // MARK: - Config Values

    lazy var _configValues: [String: ConfigValue] = {
        var _configValues: [String: ConfigValue] = [:]

        for config in configs {
            _configValues[config.key] = ConfigValue(
                key: config.key, value: config.defaultValue
            )
        }

        return _configValues
    }()

    var configValues: [ConfigValue] {
        Array(_configValues.values)
    }

    // MARK: - Methods

    func getConfig(_ key: String) -> Any {
        _configValues[key]!.value
    }

    func setConfig(key: String, value: Any) throws {
        _configValues[key] = ConfigValue(key: key, value: value)

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        try savePlugin()
    }

    func resetConfigs() throws {
        _configValues = [:]

        for config in configs {
            _configValues[config.key] = ConfigValue(
                key: config.key, value: config.defaultValue
            )
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        try savePlugin()
    }

    // MARK: - Abstract Methods

    func savePlugin() throws {
        fatalError("Not Implemented")
    }

    func deletePlugin() throws {
        fatalError("Not Implemented")
    }

    func isOnline() async throws -> Bool {
        fatalError("Not Implemented")
    }

    func getSuggestions(_: String) async throws -> [String] {
        fatalError("Not Implemented")
    }

    func search(_: String, page _: UInt) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getList(page _: UInt, genre _: Genre, status _: Status) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getMangas(_: [String]) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getManga(id: String) async throws -> Manga {
        let mangas = try await getMangas([id])

        if let manga = mangas.first {
            return manga
        } else {
            throw NSError(
                domain: "Plugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "mangaNotFound")]
            )
        }
    }

    func getDetailedManga(_: String) async throws -> DetailedManga {
        fatalError("Not Implemented")
    }

    func getChapter(manga _: DetailedManga, chapter _: Chapter) async throws -> [String] {
        fatalError("Not Implemented")
    }

    func getImage(_: String) async throws -> Data {
        fatalError("Not Implemented")
    }
}
