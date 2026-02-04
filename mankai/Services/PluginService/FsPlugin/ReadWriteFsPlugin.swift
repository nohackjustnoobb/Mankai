//
//  ReadWriteFsPlugin.swift
//  mankai
//
//  Created by Travis XU on 1/7/2025.
//

import CryptoKit
import Foundation
import GRDB
import UIKit

class ReadWriteFsPlugin: ReadFsPlugin {
    private lazy var _db: DatabasePool? = DbService.shared.openFsDb(_dbPath, readOnly: false)
    override var db: DatabasePool? {
        return _db
    }

    convenience init(url: URL) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "failedToAccessFolder")]
            )
        }
        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let idFile = url.appendingPathComponent("mankai.id")
        let id: String

        if FileManager.default.fileExists(atPath: idFile.path) {
            id = try String(contentsOf: idFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            id = UUID().uuidString
            try id.write(to: idFile, atomically: true, encoding: .utf8)
        }

        self.init(url: url, id: id)
    }

    // MARK: - Metadata

    override var tag: String? {
        String(localized: "rwfs")
    }

    // MARK: - Helper Methods

    private func getImageInfo(from imageData: Data) -> (format: String, width: Int, height: Int) {
        let format = NSData(data: imageData).imageFormat.rawValue

        if let uiImage = UIImage(data: imageData) {
            return (format, Int(uiImage.size.width), Int(uiImage.size.height))
        }

        return (format, 0, 0)
    }

    // MARK: - Methods

    func updateManga(_ manga: DetailedManga) async throws {
        Logger.fsPlugin.debug("Updating manga: \(manga.id)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for updateManga")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            let latestChapterId: Int? = {
                if let latestChapter = manga.latestChapter,
                   let latestId = latestChapter.id,
                   let latestIdInt = Int(latestId)
                {
                    return latestIdInt
                }
                return nil
            }()

            let mangaModel = FsMangaModel(
                id: manga.id,
                title: manga.title,
                status: manga.status.map { Int($0.rawValue) },
                description: manga.description,
                updatedAt: manga.updatedAt,
                authors: manga.authors.joined(separator: "|"),
                genres: manga.genres.map { $0.rawValue }.joined(separator: "|"),
                latestChapterId: latestChapterId
            )

            try mangaModel.upsert(db)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteManga(_ mangaId: String) async throws {
        Logger.fsPlugin.debug("Deleting manga: \(mangaId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for deleteManga")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        _ = try await db.write { db in
            try FsMangaModel
                .filter(Column("id") == mangaId)
                .deleteAll(db)
        }

        let fileManager = FileManager.default
        let mangaDir = url.appendingPathComponent(mangaId)

        if fileManager.fileExists(atPath: mangaDir.path) {
            try? fileManager.removeItem(at: mangaDir)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func updateCover(mangaId: String, image: Data) async throws {
        Logger.fsPlugin.debug("Updating cover for manga: \(mangaId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for updateCover")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        let fileManager = FileManager.default
        let mangaCoverDir = url.appendingPathComponent(mangaId)

        let imageInfo = getImageInfo(from: image)
        let coverFileName = "cover.\(imageInfo.format)"
        let coverId = "cover-\(mangaId)"

        if !fileManager.fileExists(atPath: mangaCoverDir.path) {
            try fileManager.createDirectory(at: mangaCoverDir, withIntermediateDirectories: true)
        }

        let coverPath = mangaCoverDir.appendingPathComponent(coverFileName)
        let relativeCoverPath = "\(mangaId)/\(coverFileName)"

        let existingCover = try await db.read { db in
            try FsImageModel
                .fetchOne(db, key: coverId)
        }

        if let existingCover = existingCover {
            let oldCoverPath = url.appendingPathComponent(existingCover.path)
            if fileManager.fileExists(atPath: oldCoverPath.path) {
                try fileManager.removeItem(at: oldCoverPath)
            }
        }

        try image.write(to: coverPath)

        try await db.write { db in
            if let existingCover = existingCover {
                var updatedCover = existingCover

                updatedCover.path = relativeCoverPath
                updatedCover.width = imageInfo.width
                updatedCover.height = imageInfo.height

                try updatedCover.update(db)
            } else {
                let coverImage = FsImageModel(
                    id: coverId,
                    path: relativeCoverPath,
                    width: imageInfo.width,
                    height: imageInfo.height,
                    mangaId: mangaId,
                    chapterId: nil
                )
                try coverImage.insert(db)
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    // MARK: - Chapter Group Methods

    func upsertChapterGroup(id: Int? = nil, mangaId: String, title: String) async throws {
        Logger.fsPlugin.debug("Upserting chapter group: \(title) for manga: \(mangaId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for upsertChapterGroup")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            let newGroup = FsChapterGroupModel(
                id: id,
                mangaId: mangaId,
                title: title
            )
            try newGroup.upsert(db)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteChapterGroup(id: Int) async throws {
        Logger.fsPlugin.debug("Deleting chapter group: \(id)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for deleteChapterGroup")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        // Fetch the chapter group and its chapters before deletion
        let (mangaId, chapterIds) = try await db.read { db in
            guard let chapterGroup = try FsChapterGroupModel.fetchOne(db, key: id) else {
                throw NSError(
                    domain: "ReadWriteFsPlugin", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Chapter group not found"]
                )
            }

            let chapters = try FsChapterModel
                .filter(Column("chapterGroupId") == id)
                .fetchAll(db)

            return (chapterGroup.mangaId, chapters.compactMap { $0.id })
        }

        // Delete chapter directories from filesystem
        let fileManager = FileManager.default
        for chapterId in chapterIds {
            let chapterDir = url
                .appendingPathComponent(mangaId)
                .appendingPathComponent("chapters")
                .appendingPathComponent(String(chapterId))

            if fileManager.fileExists(atPath: chapterDir.path) {
                try? fileManager.removeItem(at: chapterDir)
            }
        }

        // Delete the chapter group (cascade deletes chapters)
        _ = try await db.write { db in
            try FsChapterGroupModel
                .filter(key: id)
                .deleteAll(db)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func getChapterGroupId(mangaId: String, title: String) async throws -> Int? {
        guard let db = db else {
            return nil
        }

        return try await db.read { db in
            try FsChapterGroupModel
                .filter(Column("mangaId") == mangaId && Column("title") == title)
                .fetchOne(db)?.id
        }
    }

    func getChapters(groupId: Int) async throws -> [FsChapterModel] {
        guard let db = db else {
            return []
        }

        return try await db.read { db in
            let chapters = try FsChapterModel
                .filter(Column("chapterGroupId") == groupId)
                .fetchAll(db)

            return chapters.sorted { $0.sequence < $1.sequence }
        }
    }

    // MARK: - Chapter Methods

    func upsertChapter(id: Int? = nil, title: String, sequence: Int, chapterGroupId: Int) async throws {
        Logger.fsPlugin.debug("Upserting chapter: \(title) (id: \(id ?? -1), sequence: \(sequence), groupId: \(chapterGroupId))")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for upsertChapter")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            let chapter =
                try FsChapterModel(
                    id: id,
                    title: title,
                    sequence: sequence,
                    chapterGroupId: chapterGroupId
                ).upsertAndFetch(db)

            if id == nil, let newChapterId = chapter.id {
                if let chapterGroup = try FsChapterGroupModel.fetchOne(db, key: chapterGroupId) {
                    if var manga = try FsMangaModel.fetchOne(db, key: chapterGroup.mangaId) {
                        manga.latestChapterId = newChapterId
                        try manga.update(db)
                    }
                }
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteChapter(id: Int, mangaId: String) async throws {
        Logger.fsPlugin.debug("Deleting chapter: \(id) from manga: \(mangaId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for deleteChapter")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        _ = try await db.write { db in
            try FsChapterModel
                .filter(key: id)
                .deleteAll(db)
        }

        // Delete chapter directory if it exists
        let fileManager = FileManager.default
        let chapterDir = url
            .appendingPathComponent(mangaId)
            .appendingPathComponent("chapters")
            .appendingPathComponent(String(id))

        if fileManager.fileExists(atPath: chapterDir.path) {
            try? fileManager.removeItem(at: chapterDir)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func arrangeChapterOrder(ids: [Int]) async throws {
        Logger.fsPlugin.debug("Arranging chapter order for chapter group")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for arrangeChapterOrder")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            // Update sequence for each chapter based on its position in the ids array
            for (index, id) in ids.enumerated() {
                if var chapterModel = try FsChapterModel.fetchOne(db, key: id) {
                    chapterModel.sequence = index
                    try chapterModel.update(db)
                }
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func addImages(mangaId: String, chapterId: String, images: [Data]) async throws {
        Logger.fsPlugin.debug("Adding \(images.count) images to chapter: \(chapterId) (manga: \(mangaId))")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for addImages")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        let fileManager = FileManager.default
        let chapterDir =
            url
                .appendingPathComponent(mangaId)
                .appendingPathComponent("chapters")
                .appendingPathComponent(chapterId)

        if !fileManager.fileExists(atPath: chapterDir.path) {
            try fileManager.createDirectory(at: chapterDir, withIntermediateDirectories: true)
        }

        var writtenFiles: [URL] = []
        var imagePaths: [(String, String, Int, Int)] = []

        do {
            for imageData in images {
                let imageInfo = getImageInfo(from: imageData)
                let imageId = UUID().uuidString
                let imageFileName = "\(imageId).\(imageInfo.format)"

                let imagePath = chapterDir.appendingPathComponent(imageFileName)
                let relativeImagePath = "\(mangaId)/chapters/\(chapterId)/\(imageFileName)"

                try imageData.write(to: imagePath)
                writtenFiles.append(imagePath)
                imagePaths.append((relativeImagePath, imageId, imageInfo.width, imageInfo.height))
            }

            let pathsToInsert = imagePaths
            try await db.write { db in
                // Get the current max sequence for this chapter
                if let chapterIdInt = Int(chapterId) {
                    let maxSequence = try (FsImageModel
                        .filter(Column("chapterId") == chapterIdInt)
                        .select(max(Column("sequence")))
                        .asRequest(of: Int?.self)
                        .fetchOne(db) ?? nil) ?? -1

                    var currentSequence = maxSequence + 1

                    for (relativeImagePath, imageId, width, height) in pathsToInsert {
                        let imageModel = FsImageModel(
                            id: imageId,
                            path: relativeImagePath,
                            width: width,
                            height: height,
                            mangaId: nil,
                            chapterId: chapterIdInt,
                            sequence: currentSequence
                        )
                        try imageModel.insert(db)
                        currentSequence += 1
                    }
                }
            }
        } catch {
            for fileURL in writtenFiles {
                try? fileManager.removeItem(at: fileURL)
            }
            throw error
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func removeImages(ids: [String]) async throws {
        Logger.fsPlugin.debug("Removing \(ids.count) images")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for removeImages")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        let fileManager = FileManager.default

        let imageModels = try await db.read { db in
            try FsImageModel.filter(keys: ids).fetchAll(db)
        }

        for imageModel in imageModels {
            let imagePath = url.appendingPathComponent(imageModel.path)
            if fileManager.fileExists(atPath: imagePath.path) {
                try? fileManager.removeItem(at: imagePath)
            }
        }

        _ = try await db.write { db in
            try FsImageModel.filter(keys: ids).deleteAll(db)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func arrangeImageOrder(ids: [String]) async throws {
        Logger.fsPlugin.debug("Arranging image order for chapter")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for arrangeImageOrder")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            // Update sequence for each image based on its position in the ids array
            for (index, id) in ids.enumerated() {
                if var imageModel = try FsImageModel.fetchOne(db, key: id) {
                    imageModel.sequence = index
                    try imageModel.update(db)
                }
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }
}
