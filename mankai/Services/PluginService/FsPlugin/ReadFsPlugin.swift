//
//  ReadFsPlugin.swift
//  mankai
//
//  Created by Travis XU on 2/7/2025.
//

import CryptoKit
import Foundation
import GRDB

enum ReadFsPluginConstants {
    /// Maximum number of search/list results per page
    static let pageLimit: UInt = 25

    /// Maximum number of suggestions to return
    static let suggestionLimit: UInt = 5
}

class ReadFsPlugin: Plugin {
    let path: String

    // MARK: - Cache

    private lazy var dirName: String = URL(fileURLWithPath: path).lastPathComponent
    lazy var _dbPath: String = URL(fileURLWithPath: path).appendingPathComponent("data.db").path()
    private let _id: String

    private lazy var _db: DatabasePool? = DbService.shared.openFsDb(_dbPath, readOnly: true)
    var db: DatabasePool? {
        _db
    }

    init(_ path: String) {
        Logger.fsPlugin.debug("Initializing ReadFsPlugin with path: \(path)")
        self.path = path
        _id = UUID().uuidString
    }

    // MARK: - Metadata

    override var id: String {
        _id
    }

    override var tag: String? {
        String(localized: "rfs")
    }

    override var name: String? {
        dirName
    }

    override var availableGenres: [Genre] {
        Genre.allCases
    }

    // MARK: - Override Methods

    override func savePlugin() throws {
        fatalError("Not Implemented")
    }

    override func deletePlugin() throws {
        fatalError("Not Implemented")
    }

    override func isOnline() async throws -> Bool {
        db != nil
    }

    // MARK: - Helper Functions

    private func convertToManga(_ mangaModel: FsMangaModel, db: Database) throws -> Manga? {
        let cover = try mangaModel.cover.fetchOne(db)
        let latestChapter = try mangaModel.latestChapter.fetchOne(db)

        var mangaDict: [String: Any] = [
            "id": mangaModel.id,
        ]

        if let title = mangaModel.title {
            mangaDict["title"] = title
        }

        if let coverPath = cover?.path {
            mangaDict["cover"] = coverPath
        }

        if let status = mangaModel.status {
            mangaDict["status"] = UInt(status)
        }

        if let chapter = latestChapter {
            mangaDict["latestChapter"] = [
                "id": chapter.id.flatMap { String($0) },
                "title": chapter.title,
            ]
        }

        return Manga(from: mangaDict)
    }

    private func convertToDetailedManga(_ mangaModel: FsMangaModel, db: Database) throws
        -> DetailedManga?
    {
        let cover = try mangaModel.cover.fetchOne(db)
        let latestChapter = try mangaModel.latestChapter.fetchOne(db)
        let chapterGroups = try mangaModel.chapters.fetchAll(db)

        var mangaDict: [String: Any] = [
            "id": mangaModel.id,
        ]

        if let title = mangaModel.title {
            mangaDict["title"] = title
        }

        if let coverPath = cover?.path {
            mangaDict["cover"] = coverPath
        }

        if let status = mangaModel.status {
            mangaDict["status"] = UInt(status)
        }

        if let description = mangaModel.description {
            mangaDict["description"] = description
        }

        if let updatedAt = mangaModel.updatedAt {
            mangaDict["updatedAt"] = Int64(updatedAt.timeIntervalSince1970 * 1000)
        }

        let authors = mangaModel.authors.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        mangaDict["authors"] = authors

        let genres = mangaModel.genres.components(separatedBy: "|").map {
            $0.trimmingCharacters(in: .whitespaces)
        }.filter { !$0.isEmpty }
        mangaDict["genres"] = genres

        if let chapter = latestChapter {
            mangaDict["latestChapter"] = [
                "id": chapter.id.flatMap { String($0) },
                "title": chapter.title,
            ]
        }

        var chaptersDict: [String: [[String: Any?]]] = [:]
        for group in chapterGroups {
            let chapters = try group.chapters.fetchAll(db)
            let chaptersArray = chapters.map { chapter in
                [
                    "id": String(chapter.id!),
                    "title": chapter.title,
                ] as [String: Any?]
            }

            // Build a dictionary for fast lookup
            let chapterDict = Dictionary(
                uniqueKeysWithValues: chaptersArray.compactMap { item in
                    (item["id"] as! String, item)
                })
            let orderIds = group.order.components(separatedBy: "|").map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            let sortedChaptersArray = orderIds.compactMap { chapterDict[$0] }
            chaptersDict[group.title] = sortedChaptersArray
        }
        mangaDict["chapters"] = chaptersDict

        return DetailedManga(from: mangaDict)
    }

    override func getSuggestions(_ query: String) async throws -> [String] {
        Logger.fsPlugin.debug("Getting suggestions for query: \(query)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for suggestions")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        return try await db.read { db in
            let searchQuery = "%\(query.lowercased())%"
            let mangas =
                try FsMangaModel
                    .filter(sql: "LOWER(title) LIKE ?", arguments: [searchQuery])
                    .limit(Int(ReadFsPluginConstants.suggestionLimit))
                    .fetchAll(db)

            return mangas.compactMap { $0.title }
        }
    }

    override func search(_ query: String, page: UInt) async throws -> [Manga] {
        Logger.fsPlugin.debug("Searching for: \(query), page: \(page)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for search")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        return try await db.read { db in
            let searchQuery = "%\(query.lowercased())%"
            let offset = Int((page - 1) * ReadFsPluginConstants.pageLimit)
            let limit = Int(ReadFsPluginConstants.pageLimit)

            let mangas =
                try FsMangaModel
                    .filter(sql: "LOWER(title) LIKE ?", arguments: [searchQuery])
                    .limit(limit, offset: offset)
                    .fetchAll(db)

            return try mangas.compactMap { mangaModel in
                try self.convertToManga(mangaModel, db: db)
            }
        }
    }

    override func getList(page: UInt, genre: Genre, status: Status) async throws -> [Manga] {
        Logger.fsPlugin.debug("Getting list, page: \(page), genre: \(genre), status: \(status)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for list")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        return try await db.read { db in
            let offset = Int((page - 1) * ReadFsPluginConstants.pageLimit)
            let limit = Int(ReadFsPluginConstants.pageLimit)

            var query = FsMangaModel.all()

            // Filter by genre if not "all"
            if genre != .all {
                let genreQuery = "%\(genre.rawValue)%"
                query = query.filter(sql: "LOWER(genres) LIKE ?", arguments: [genreQuery])
            }

            // Filter by status if not "any"
            if status != .any {
                query = query.filter(Column("status") == Int(status.rawValue))
            }

            let mangas =
                try query
                    .limit(limit, offset: offset)
                    .fetchAll(db)

            return try mangas.compactMap { mangaModel in
                try self.convertToManga(mangaModel, db: db)
            }
        }
    }

    override func getMangas(_ ids: [String]) async throws -> [Manga] {
        Logger.fsPlugin.debug("Getting \(ids.count) mangas")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for getMangas")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        return try await db.read { db in
            let mangas =
                try FsMangaModel
                    .filter(ids.contains(Column("id")))
                    .fetchAll(db)

            return try mangas.compactMap { mangaModel in
                try self.convertToManga(mangaModel, db: db)
            }
        }
    }

    override func getDetailedManga(_ id: String) async throws -> DetailedManga {
        Logger.fsPlugin.debug("Getting detailed manga: \(id)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for getDetailedManga")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        return try await db.read { db in
            guard let mangaModel = try FsMangaModel.fetchOne(db, key: id) else {
                Logger.fsPlugin.warning("Manga not found in DB: \(id)")
                throw NSError(
                    domain: "ReadFsPlugin", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "mangaDirectoryNotFound")]
                )
            }

            guard let detailedManga = try self.convertToDetailedManga(mangaModel, db: db) else {
                Logger.fsPlugin.error("Failed to convert manga model to detailed manga: \(id)")
                throw NSError(
                    domain: "ReadFsPlugin", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "failedToLoadMangaDetails")]
                )
            }

            return detailedManga
        }
    }

    override func getChapter(manga _: DetailedManga, chapter: Chapter) async throws -> [String] {
        Logger.fsPlugin.debug("Getting chapter: \(chapter.id ?? "nil")")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for getChapter")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        guard let chapterId = chapter.id, let chapterIdInt = Int(chapterId) else {
            Logger.fsPlugin.error("Invalid chapter ID: \(String(describing: chapter.id))")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidMangaOrChapterFormat")]
            )
        }

        return try await db.read { db in
            guard let chapterModel = try FsChapterModel.fetchOne(db, key: chapterIdInt) else {
                Logger.fsPlugin.warning("Chapter not found in DB: \(chapterIdInt)")
                throw NSError(
                    domain: "ReadFsPlugin", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "chapterDirectoryNotFound")]
                )
            }

            let imageIds = chapterModel.order.components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            let images =
                try FsImageModel
                    .filter(Column("chapterId") == chapterIdInt)
                    .fetchAll(db)

            let imageDict = Dictionary(uniqueKeysWithValues: images.map { ($0.id, $0.path) })

            return imageIds.compactMap { imageDict[$0] }
        }
    }

    override func getImage(_ url: String) async throws -> Data {
        Logger.fsPlugin.debug("Getting image: \(url)")
        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)
        let fullImagePath = pathURL.appendingPathComponent(url).path

        guard fileManager.fileExists(atPath: fullImagePath) else {
            Logger.fsPlugin.error("Image file not found: \(fullImagePath)")
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "failedToLoadImage")]
            )
        }

        do {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: fullImagePath))
            return imageData
        } catch {
            Logger.fsPlugin.error("Failed to load image data: \(fullImagePath)", error: error)
            throw NSError(
                domain: "ReadFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "failedToLoadImage")]
            )
        }
    }
}
