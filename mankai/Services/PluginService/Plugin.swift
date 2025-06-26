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
    var option: Any?
}

class Plugin: Identifiable {
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

    // ----------- Methods -----------

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
