//
//  ReadFsPlugin.swift
//  mankai
//
//  Created by Travis XU on 2/7/2025.
//

import CryptoKit
import Foundation

enum ReadFsPluginConstants {
    /// Maximum number of search/list results per page
    static let pageLimit: UInt = 25

    /// Maximum number of suggestions to return
    static let suggestionLimit: UInt = 5

    /// Default cache expiry duration in seconds (1 hour)
    static let defaultCacheExpiryDuration: TimeInterval = 3600

    /// Maximum number of cache entries before triggering cleanup of expired entries
    static let maxCacheSize: Int = 100
}

class ReadFsPlugin: Plugin {
    let path: String

    // MARK: - Cache

    private var metaCache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()

    lazy var hash: String = {
        let digest = Insecure.MD5.hash(data: Data(path.utf8))

        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }()

    lazy var dirName: String = URL(fileURLWithPath: path).lastPathComponent

    init(_ path: String) {
        self.path = path
    }

    // MARK: - Metadata

    override var id: String {
        hash
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

    // MARK: - Cache Methods

    private func getCacheExpiryDuration() -> TimeInterval {
        let defaults = UserDefaults.standard
        let duration = defaults.double(forKey: SettingsKey.cacheExpiryDuration.rawValue)
        return duration > 0 ? duration : ReadFsPluginConstants.defaultCacheExpiryDuration
    }

    private func getCacheKey(for mangaId: String) -> String {
        return mangaId
    }

    private func getCachedMetaDict(for key: String) -> [String: Any]? {
        // Periodically clear expired cache entries
        if metaCache.count > ReadFsPluginConstants.maxCacheSize {
            clearExpiredCache()
        }

        guard let entry = metaCache[key], !entry.isExpired else {
            removeExpiredEntry(for: key)
            return nil
        }

        return entry.data as? [String: Any]
    }

    private func setCachedMetaDict(_ data: [String: Any], for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let expiryTime = Date().addingTimeInterval(getCacheExpiryDuration())
        metaCache[key] = CacheEntry(data: data, expiryTime: expiryTime)
    }

    func removeExpiredEntry(for key: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        metaCache.removeValue(forKey: key)
    }

    private func clearExpiredCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        metaCache = metaCache.filter { _, entry in
            !entry.isExpired
        }
    }

    // Public method to clear cache manually
    func clearAllCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        metaCache.removeAll()
    }

    // MARK: - Override Methods

    override func savePlugin() throws {
        fatalError("Not Implemented")
    }

    override func deletePlugin() throws {
        fatalError("Not Implemented")
    }

    override func isOnline() async throws -> Bool {
        // TODO: may have remote source
        true
    }

    private func searchMetaByQuery<T>(
        query: String, limit: Int, map: @escaping ([String: Any]) -> T?
    ) -> [T] {
        let lowercasedQuery = query.lowercased()
        var results: [T] = []
        var checkedKeys: Set<String> = []

        for (key, entry) in metaCache {
            if entry.isExpired { continue }

            checkedKeys.insert(key)
            if let metaDict = entry.data as? [String: Any] {
                let title = metaDict["title"] as? String
                let desc = metaDict["description"] as? String

                if (title?.lowercased().contains(lowercasedQuery) == true)
                    || (desc?.lowercased().contains(lowercasedQuery) == true)
                {
                    if let mapped = map(metaDict) { results.append(mapped) }
                }
            }

            if results.count >= limit { break }
        }

        if results.count < limit {
            let fileManager = FileManager.default
            let pathURL = URL(fileURLWithPath: path)
            let contents = try? fileManager.contentsOfDirectory(atPath: pathURL.path)
            let mangaDirectories =
                contents?.filter { item in
                    var isDir: ObjCBool = false
                    let itemURL = pathURL.appendingPathComponent(item)
                    return fileManager.fileExists(atPath: itemURL.path, isDirectory: &isDir)
                        && isDir.boolValue
                } ?? []

            for mangaId in mangaDirectories {
                let cacheKey = getCacheKey(for: mangaId)
                if checkedKeys.contains(cacheKey) { continue }

                let mangaPath = pathURL.appendingPathComponent(mangaId)
                let metaPath = mangaPath.appendingPathComponent("meta.json")
                guard fileManager.fileExists(atPath: metaPath.path) else { continue }

                do {
                    let metaData = try Data(contentsOf: metaPath)
                    if let metaDict = try JSONSerialization.jsonObject(with: metaData, options: [])
                        as? [String: Any]
                    {
                        setCachedMetaDict(metaDict, for: cacheKey)

                        let title = metaDict["title"] as? String
                        let desc = metaDict["description"] as? String

                        if (title?.lowercased().contains(lowercasedQuery) == true)
                            || (desc?.lowercased().contains(lowercasedQuery) == true)
                        {
                            if let mapped = map(metaDict) { results.append(mapped) }
                        }
                    }

                } catch { continue }

                if results.count >= limit { break }
            }
        }

        return Array(results.prefix(limit))
    }

    override func getSuggestions(_ query: String) async throws -> [String] {
        let suggestionLimit = Int(ReadFsPluginConstants.suggestionLimit)
        return searchMetaByQuery(query: query, limit: suggestionLimit) { metaDict in
            metaDict["title"] as? String
        }
    }

    override func search(_ query: String, page: UInt) async throws -> [Manga] {
        let limit = Int(ReadFsPluginConstants.pageLimit)

        let startIndex = Int((page - 1) * UInt(limit))
        let endIndex = startIndex + limit

        let allResults = searchMetaByQuery(query: query, limit: endIndex + 1) { metaDict in
            Manga(from: metaDict)
        }

        if startIndex >= allResults.count { return [] }
        return Array(allResults[startIndex..<min(endIndex, allResults.count)])
    }

    override func getList(page: UInt, genre: Genre, status: Status) async throws -> [Manga] {
        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: pathURL.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: pathURL.path)
        var mangaDirectories: [String] = []

        for item in contents {
            let itemURL = pathURL.appendingPathComponent(item)
            var itemIsDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: itemURL.path, isDirectory: &itemIsDirectory)
                && itemIsDirectory.boolValue
            {
                mangaDirectories.append(item)
            }
        }

        mangaDirectories.sort()

        let limit = ReadFsPluginConstants.pageLimit
        let startIndex = Int((page - 1) * limit)
        let endIndex = min(startIndex + Int(limit), mangaDirectories.count)

        guard startIndex < mangaDirectories.count else {
            return []
        }

        let pageDirectories = Array(mangaDirectories[startIndex..<endIndex])
        var mangas: [Manga] = []

        for mangaId in pageDirectories {
            let mangaPath = pathURL.appendingPathComponent(mangaId)
            let metaPath = mangaPath.appendingPathComponent("meta.json")

            guard fileManager.fileExists(atPath: metaPath.path) else {
                continue
            }

            let cacheKey = getCacheKey(for: mangaId)
            var metaDict: [String: Any]?

            if let cachedDict = getCachedMetaDict(for: cacheKey) {
                metaDict = cachedDict
            } else {
                do {
                    let metaData = try Data(contentsOf: metaPath)
                    metaDict =
                        try JSONSerialization.jsonObject(with: metaData, options: [])
                            as? [String: Any]

                    if let dict = metaDict {
                        setCachedMetaDict(dict, for: cacheKey)
                    }
                } catch {
                    continue
                }
            }

            if let metaDict = metaDict, let manga = Manga(from: metaDict) {
                if genre != .all {
                    if let metaGenres = metaDict["genres"] as? [String] {
                        if !metaGenres.contains(genre.rawValue) {
                            continue
                        }
                    } else {
                        continue
                    }
                }

                if status != .any {
                    if manga.status != status {
                        continue
                    }
                }

                mangas.append(manga)
            }
        }

        return mangas
    }

    override func getMangas(_ ids: [String]) async throws -> [Manga] {
        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)
        var mangas: [Manga] = []

        for mangaId in ids {
            let cacheKey = getCacheKey(for: mangaId)
            var metaDict: [String: Any]?

            if let cachedDict = getCachedMetaDict(for: cacheKey) {
                metaDict = cachedDict
            } else {
                let mangaPath = pathURL.appendingPathComponent(mangaId)
                let metaPath = mangaPath.appendingPathComponent("meta.json")

                guard fileManager.fileExists(atPath: metaPath.path) else {
                    continue
                }

                do {
                    let metaData = try Data(contentsOf: metaPath)
                    metaDict =
                        try JSONSerialization.jsonObject(with: metaData, options: [])
                            as? [String: Any]

                    if let dict = metaDict {
                        setCachedMetaDict(dict, for: cacheKey)
                    }
                } catch {
                    continue
                }
            }

            if let metaDict = metaDict, let manga = Manga(from: metaDict) {
                mangas.append(manga)
            }
        }

        return mangas
    }

    override func getDetailedManga(_ id: String) async throws -> DetailedManga {
        let cacheKey = getCacheKey(for: id)
        var metaDict: [String: Any]?

        if let cachedDict = getCachedMetaDict(for: cacheKey) {
            metaDict = cachedDict
        } else {
            let fileManager = FileManager.default
            let pathURL = URL(fileURLWithPath: path)
            let mangaPath = pathURL.appendingPathComponent(id)
            let metaPath = mangaPath.appendingPathComponent("meta.json")

            guard fileManager.fileExists(atPath: metaPath.path) else {
                throw NSError(
                    domain: "ReadFsPlugin", code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "mangaDirectoryNotFound"])
            }

            do {
                let metaData = try Data(contentsOf: metaPath)
                metaDict =
                    try JSONSerialization.jsonObject(with: metaData, options: []) as? [String: Any]

                if let dict = metaDict {
                    setCachedMetaDict(dict, for: cacheKey)
                }
            } catch {
                throw error
            }
        }

        guard let metaDict = metaDict, let detailedManga = DetailedManga(from: metaDict) else {
            throw NSError(
                domain: "ReadFsPlugin", code: 500,
                userInfo: [NSLocalizedDescriptionKey: "invalidResultFormatForDetailedManga"])
        }

        return detailedManga
    }

    override func getChapter(manga: DetailedManga, chapter: Chapter) async throws -> [String] {
        guard let chapterId = chapter.id else {
            throw NSError(
                domain: "ReadFsPlugin", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "invalidMangaOrChapterFormat"])
        }

        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)
        let chapterPath = pathURL.appendingPathComponent(manga.id).appendingPathComponent(chapterId)

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: chapterPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "ReadFsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "chapterDirectoryNotFound"])
        }

        let metaPath = chapterPath.appendingPathComponent("meta.json")
        guard fileManager.fileExists(atPath: metaPath.path) else {
            return []
        }
        let metaData = try Data(contentsOf: metaPath)
        guard
            let hashes = try? JSONSerialization.jsonObject(with: metaData, options: []) as? [String]
        else {
            return []
        }

        var imagePaths: [String] = []
        let contents = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
        for hash in hashes {
            if let fileName = contents.first(where: { $0.hasPrefix(hash + ".") }) {
                imagePaths.append("\(manga.id)/\(chapterId)/\(fileName)")
            }
        }
        return imagePaths
    }

    override func getImage(_ url: String) async throws -> Data {
        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)
        let fullImagePath = pathURL.appendingPathComponent(url).path

        guard fileManager.fileExists(atPath: fullImagePath) else {
            throw NSError(
                domain: "ReadFsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "failedToLoadImage"])
        }

        do {
            let imageData = try Data(contentsOf: URL(fileURLWithPath: fullImagePath))
            return imageData
        } catch {
            throw NSError(
                domain: "ReadFsPlugin", code: 500,
                userInfo: [NSLocalizedDescriptionKey: "failedToLoadImage"])
        }
    }
}
