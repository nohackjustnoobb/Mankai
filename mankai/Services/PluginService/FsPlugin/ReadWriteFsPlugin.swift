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

            var mangaModel = FsMangaModel(
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

            // Delete chapters
            let chaptersId = manga.chapters.flatMap { _, chapters in
                chapters.compactMap { chapter in
                    chapter.id.flatMap { String($0) }
                }
            }
            let chapterIdsToDelete: [Int] =
                try FsChapterModel
                    .filter(!chaptersId.contains(Column("id")))
                    .fetchAll(db)
                    .map { $0.id! }
            try FsChapterModel
                .filter(keys: chapterIdsToDelete)
                .deleteAll(db)

            let fileManager = FileManager.default
            let pathURL = URL(fileURLWithPath: self.path)
                .appendingPathComponent(manga.id)
            for chapterId in chapterIdsToDelete {
                let chapterDir =
                    pathURL
                        .appendingPathComponent("chapters")
                        .appendingPathComponent(String(chapterId))

                if fileManager.fileExists(atPath: chapterDir.path) {
                    try? fileManager.removeItem(at: chapterDir)
                }
            }

            // Create or update chapter groups
            let chapterKeys = Set(manga.chapters.map { $0.key })

            let chapterKeysToDelete: [Int] =
                try FsChapterGroupModel
                    .filter(!chapterKeys.contains(Column("title")) && Column("mangaId") == manga.id)
                    .fetchAll(db)
                    .map { $0.id! }

            let existingChapterGroupTitles: [String] =
                try FsChapterGroupModel
                    .filter(Column("mangaId") == manga.id)
                    .fetchAll(db)
                    .map { $0.title }
            let missingChapterGroupKeys = chapterKeys.filter { !existingChapterGroupTitles.contains($0) }

            for key in missingChapterGroupKeys {
                let chapterGroup = FsChapterGroupModel(
                    mangaId: manga.id,
                    title: key,
                    order: ""
                )
                try chapterGroup.insert(db)
            }

            // Update chapters
            let allChapterGroups =
                try FsChapterGroupModel
                    .filter(Column("mangaId") == manga.id)
                    .fetchAll(db)
            var chapterGroupIdByKey: [String: Int] = [:]
            for group in allChapterGroups {
                if let groupId = group.id {
                    chapterGroupIdByKey[group.title] = groupId
                }
            }

            var chapterInfoById: [Int: (title: String, chapterKey: String)] = [:]
            var chapterIdsByKey: [String: [Int]] = [:]
            for (chapterKey, chapters) in manga.chapters {
                for chapter in chapters {
                    if let chapterIdStr = chapter.id, let chapterId = Int(chapterIdStr) {
                        chapterInfoById[chapterId] = (chapter.title ?? "", chapterKey)
                        chapterIdsByKey[chapterKey, default: []].append(chapterId)
                    } else {
                        let groupId = chapterGroupIdByKey[chapterKey]!
                        var newChapter = FsChapterModel(
                            title: chapter.title ?? "",
                            order: "",
                            chapterGroupId: groupId
                        )
                        newChapter = try newChapter.insertAndFetch(db)

                        if let newId = newChapter.id {
                            chapterInfoById[newId] = (chapter.title ?? "", chapterKey)
                            chapterIdsByKey[chapterKey, default: []].append(newId)

                            if manga.latestChapter?.title == chapter.title {
                                mangaModel.latestChapterId = newId
                                try mangaModel.update(db)
                            }
                        }
                    }
                }
            }

            let existingChapters =
                try FsChapterModel
                    .filter(chaptersId.contains(Column("id")))
                    .fetchAll(db)
            for var existingChapter in existingChapters {
                if let info = chapterInfoById[existingChapter.id ?? -1],
                   let groupId = chapterGroupIdByKey[info.chapterKey]
                {
                    existingChapter.title = info.title
                    existingChapter.chapterGroupId = groupId
                    try existingChapter.update(db)
                }
            }

            // Delete chapter groups that are no longer needed
            try FsChapterGroupModel
                .filter(keys: chapterKeysToDelete)
                .deleteAll(db)

            // Update the order of chapters in each group
            for (chapterKey, chapterIds) in chapterIdsByKey {
                if let groupId = chapterGroupIdByKey[chapterKey] {
                    let chapterOrder = chapterIds.map { String($0) }.joined(separator: "|")
                    let chapterGroup = FsChapterGroupModel(
                        id: groupId,
                        mangaId: manga.id,
                        title: chapterKey,
                        order: chapterOrder
                    )
                    try chapterGroup.update(db)
                }
            }
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
        let pathURL = URL(fileURLWithPath: path)
        let mangaDir = pathURL.appendingPathComponent(mangaId)

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
        let pathURL = URL(fileURLWithPath: path)
        let mangaCoverDir = pathURL.appendingPathComponent(mangaId)

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
            let oldCoverPath = pathURL.appendingPathComponent(existingCover.path)
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
        let pathURL = URL(fileURLWithPath: path)
        let chapterDir =
            pathURL
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
                var imageIds: [String] = []

                for (relativeImagePath, imageId, width, height) in pathsToInsert {
                    var imageModel = FsImageModel(
                        id: imageId,
                        path: relativeImagePath,
                        width: width,
                        height: height,
                        mangaId: nil,
                        chapterId: Int(chapterId)
                    )
                    imageModel = try imageModel.insertAndFetch(db)

                    imageIds.append(imageModel.id)
                }

                if let chapterIdInt = Int(chapterId) {
                    if var chapterModel = try FsChapterModel.fetchOne(db, key: chapterIdInt) {
                        let existingIds =
                            chapterModel.order.isEmpty ? [] : chapterModel.order.components(separatedBy: "|")
                        let newOrder = existingIds + imageIds
                        chapterModel.order = newOrder.joined(separator: "|")
                        try chapterModel.update(db)
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

    func removeImages(mangaId _: String, chapterId: String, ids: [String]) async throws {
        Logger.fsPlugin.debug("Removing \(ids.count) images from chapter: \(chapterId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for removeImages")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        let fileManager = FileManager.default
        let pathURL = URL(fileURLWithPath: path)

        let imageModels = try await db.read { db in
            let imageIds = ids.compactMap { Int($0) }
            return try FsImageModel.filter(keys: imageIds).fetchAll(db)
        }

        try await db.write { db in
            let imageIds = ids.compactMap { Int($0) }
            try FsImageModel.filter(keys: imageIds).deleteAll(db)

            if let chapterIdInt = Int(chapterId) {
                if var chapterModel = try FsChapterModel.fetchOne(db, key: chapterIdInt) {
                    let currentIds = chapterModel.order.components(separatedBy: "|")
                        .filter { !ids.contains($0) && !$0.isEmpty }

                    chapterModel.order = currentIds.joined(separator: "|")
                    try chapterModel.update(db)
                }
            }
        }

        for imageModel in imageModels {
            let imagePath = pathURL.appendingPathComponent(imageModel.path)
            if fileManager.fileExists(atPath: imagePath.path) {
                try? fileManager.removeItem(at: imagePath)
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func arrangeImageOrder(mangaId _: String, chapterId: String, ids: [String]) async throws {
        Logger.fsPlugin.debug("Arranging image order for chapter: \(chapterId)")
        guard let db = db else {
            Logger.fsPlugin.error("Database not available for arrangeImageOrder")
            throw NSError(
                domain: "ReadWriteFsPlugin", code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(localized: "databaseNotAvailable")]
            )
        }

        try await db.write { db in
            if let chapterIdInt = Int(chapterId) {
                if var chapterModel = try FsChapterModel.fetchOne(db, key: chapterIdInt) {
                    chapterModel.order = ids.joined(separator: "|")
                    try chapterModel.update(db)
                }
            }
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }
}
