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
    // ----------- Metadata -----------

    var id: String {
        fatalError("Not Implemented")
    }

    var name: String? {
        fatalError("Not Implemented")
    }

    var version: String? {
        fatalError("Not Implemented")
    }

    var description: String? {
        fatalError("Not Implemented")
    }

    var authors: [String] {
        fatalError("Not Implemented")
    }

    var repository: String? {
        fatalError("Not Implemented")
    }

    var updatesUrl: String? {
        fatalError("Not Implemented")
    }

    var availableGenres: [Genre] {
        fatalError("Not Implemented")
    }

    var configs: [Config] {
        fatalError("Not Implemented")
    }

    // ----------- Config Values -----------

    lazy var _configValues: [String: ConfigValue] = {
        var _configValues: [String: ConfigValue] = [:]

        for config in configs {
            _configValues[config.key] = ConfigValue(
                key: config.key, value: config.defaultValue)
        }

        return _configValues
    }()

    var configValues: [ConfigValue] {
        Array(_configValues.values)
    }

    // ----------- Methods -----------

    func getConfig(_ key: String) -> Any {
        _configValues[key]!.value
    }

    func setConfig(key: String, value: Any) throws {
        _configValues[key] = ConfigValue(key: key, value: value)

        objectWillChange.send()

        try savePlugin()
    }

    func resetConfigs() throws {
        _configValues = [:]

        for config in configs {
            _configValues[config.key] = ConfigValue(
                key: config.key, value: config.defaultValue)
        }

        objectWillChange.send()

        try savePlugin()
    }

    // ----------- Abstract Methods -----------

    func savePlugin() throws {
        fatalError("Not Implemented")
    }

    func deletePlugin() throws {
        fatalError("Not Implemented")
    }

    func isOnline() async throws -> Bool {
        fatalError("Not Implemented")
    }

    func getSuggestions(_ query: String) async throws -> [String] {
        fatalError("Not Implemented")
    }

    func search(_ query: String, page: UInt) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getList(page: UInt, genre: Genre, status: Status) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getMangas(_ ids: [String]) async throws -> [Manga] {
        fatalError("Not Implemented")
    }

    func getDetailedManga(_ id: String) async throws -> DetailedManga {
        fatalError("Not Implemented")
    }

    func getChapter(manga: DetailedManga, chapter: Chapter) async throws -> [String] {
        fatalError("Not Implemented")
    }

    func getImage(_ url: String) async throws -> Data {
        fatalError("Not Implemented")
    }
}
