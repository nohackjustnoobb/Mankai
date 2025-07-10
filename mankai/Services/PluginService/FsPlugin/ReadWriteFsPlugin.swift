//
//  ReadWriteFsPlugin.swift
//  mankai
//
//  Created by Travis XU on 1/7/2025.
//

import CryptoKit
import Foundation

class ReadWriteFsPlugin: ReadFsPlugin {
    // MARK: - Metadata

    override var tag: String? {
        String(localized: "rwfs")
    }

    // MARK: - Methods

    func updateManga(_ manga: DetailedManga) async throws {
        let mangaPath = URL(fileURLWithPath: path).appendingPathComponent(manga.id)
        let metaPath = mangaPath.appendingPathComponent("meta.json")
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        let mangaDirectoryExists =
            fileManager.fileExists(atPath: mangaPath.path, isDirectory: &isDirectory)
                && isDirectory.boolValue

        if mangaDirectoryExists {
            let mangaData = try JSONEncoder().encode(manga)
            try mangaData.write(to: metaPath)

            let existingItems = try fileManager.contentsOfDirectory(atPath: mangaPath.path)
            let existingChapterDirectories = existingItems.filter { item in
                let itemPath = mangaPath.appendingPathComponent(item)
                var isDir: ObjCBool = false
                return fileManager.fileExists(atPath: itemPath.path, isDirectory: &isDir)
                    && isDir.boolValue && item != "meta.json"
            }

            let validChapterIds = Set(
                manga.chapters.values.flatMap { chapters in
                    chapters.compactMap { $0.id }
                })

            for chapterDirectory in existingChapterDirectories {
                if !validChapterIds.contains(chapterDirectory) {
                    let chapterPath = mangaPath.appendingPathComponent(chapterDirectory)
                    try fileManager.removeItem(at: chapterPath)
                }
            }

            for chapterId in validChapterIds {
                let chapterPath = mangaPath.appendingPathComponent(chapterId)
                var isDir: ObjCBool = false
                let chapterExists =
                    fileManager.fileExists(atPath: chapterPath.path, isDirectory: &isDir)
                        && isDir.boolValue

                if !chapterExists {
                    try fileManager.createDirectory(
                        at: chapterPath, withIntermediateDirectories: false, attributes: nil)
                }
            }
        } else {
            try fileManager.createDirectory(
                at: mangaPath, withIntermediateDirectories: true, attributes: nil)
            let mangaData = try JSONEncoder().encode(manga)
            try mangaData.write(to: metaPath)

            let validChapterIds = Set(
                manga.chapters.values.flatMap { chapters in
                    chapters.compactMap { $0.id }
                })

            for chapterId in validChapterIds {
                let chapterPath = mangaPath.appendingPathComponent(chapterId)
                try fileManager.createDirectory(
                    at: chapterPath, withIntermediateDirectories: false, attributes: nil)
            }
        }

        removeExpiredEntry(for: manga.id)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteManga(_ mangaId: String) async throws {
        let mangaPath = URL(fileURLWithPath: path).appendingPathComponent(mangaId)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: mangaPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "FsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "mangaDirectoryNotFound"])
        }

        try fileManager.removeItem(at: mangaPath)

        removeExpiredEntry(for: mangaId)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func updateCover(mangaId: String, image: Data) async throws {
        let mangaPath = URL(fileURLWithPath: path).appendingPathComponent(mangaId)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: mangaPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "FsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "mangaDirectoryNotFound"])
        }

        let imageFormat = NSData(data: image).imageFormat
        let newCoverFileName = "cover.\(imageFormat.rawValue)"
        let coverPath = mangaPath.appendingPathComponent(newCoverFileName)

        let existingFiles = try fileManager.contentsOfDirectory(atPath: mangaPath.path)
        let existingCover = existingFiles.first(where: { $0.hasPrefix("cover.") })
        let coverFileChanged = (existingCover != newCoverFileName)
        if let existingCover = existingCover {
            let existingCoverPath = mangaPath.appendingPathComponent(existingCover)
            try? fileManager.removeItem(at: existingCoverPath)
        }

        try image.write(to: coverPath)

        let metaPath = mangaPath.appendingPathComponent("meta.json")
        if coverFileChanged, fileManager.fileExists(atPath: metaPath.path) {
            let metaData = try Data(contentsOf: metaPath)
            if var metaDict = try JSONSerialization.jsonObject(with: metaData, options: [])
                as? [String: Any]
            {
                metaDict["cover"] = "\(mangaId)/\(newCoverFileName)"
                let updatedMetaData = try JSONSerialization.data(
                    withJSONObject: metaDict, options: .prettyPrinted)
                try updatedMetaData.write(to: metaPath)
            }

            removeExpiredEntry(for: mangaId)
        }

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func addImages(mangaId: String, chapterId: String, images: [Data]) async throws {
        let chapterPath = URL(fileURLWithPath: path)
            .appendingPathComponent(mangaId)
            .appendingPathComponent(chapterId)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: chapterPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "FsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "chapterDirectoryNotFound"])
        }

        let metaPath = chapterPath.appendingPathComponent("meta.json")
        var imageOrder: [String] = []
        if fileManager.fileExists(atPath: metaPath.path) {
            let metaData = try Data(contentsOf: metaPath)
            if let arr = try? JSONSerialization.jsonObject(with: metaData, options: []) as? [String] {
                imageOrder = arr
            }
        }

        for imageData in images {
            var uuid = UUID().uuidString
            while imageOrder.contains(uuid) {
                uuid = UUID().uuidString
            }
            let imageFormat = NSData(data: imageData).imageFormat
            let fileName = "\(uuid).\(imageFormat.rawValue)"
            let imagePath = chapterPath.appendingPathComponent(fileName)

            try imageData.write(to: imagePath)
            imageOrder.append(uuid)
        }

        let updatedMetaData = try JSONSerialization.data(
            withJSONObject: imageOrder, options: [])
        try updatedMetaData.write(to: metaPath)
    }

    func removeImages(mangaId: String, chapterId: String, ids: [String]) async throws {
        let chapterPath = URL(fileURLWithPath: path)
            .appendingPathComponent(mangaId)
            .appendingPathComponent(chapterId)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: chapterPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "FsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "chapterDirectoryNotFound"])
        }

        let metaPath = chapterPath.appendingPathComponent("meta.json")
        var imageOrder: [String] = []
        if fileManager.fileExists(atPath: metaPath.path) {
            let metaData = try Data(contentsOf: metaPath)
            if let arr = try? JSONSerialization.jsonObject(with: metaData, options: []) as? [String] {
                imageOrder = arr
            }
        }

        for id in ids {
            let files = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
            for file in files {
                if file.hasPrefix(id + ".") {
                    let imagePath = chapterPath.appendingPathComponent(file)
                    if fileManager.fileExists(atPath: imagePath.path) {
                        try fileManager.removeItem(at: imagePath)
                    }
                }
            }
        }

        imageOrder.removeAll { ids.contains($0) }
        let updatedMetaData = try JSONSerialization.data(
            withJSONObject: imageOrder, options: .prettyPrinted)
        try updatedMetaData.write(to: metaPath)
    }

    func arrangeImageOrder(mangaId: String, chapterId: String, ids: [String]) async throws {
        let chapterPath = URL(fileURLWithPath: path)
            .appendingPathComponent(mangaId)
            .appendingPathComponent(chapterId)
        let fileManager = FileManager.default

        var isDirectory: ObjCBool = false
        guard
            fileManager.fileExists(atPath: chapterPath.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
        else {
            throw NSError(
                domain: "FsPlugin", code: 404,
                userInfo: [NSLocalizedDescriptionKey: "chapterDirectoryNotFound"])
        }

        let metaPath = chapterPath.appendingPathComponent("meta.json")
        var imageOrder: [String] = []
        if fileManager.fileExists(atPath: metaPath.path) {
            let metaData = try Data(contentsOf: metaPath)
            if let arr = try? JSONSerialization.jsonObject(with: metaData, options: []) as? [String] {
                imageOrder = arr
            }
        }

        guard ids.count == imageOrder.count else {
            throw NSError(
                domain: "FsPlugin", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "ordersCountMismatch"])
        }

        imageOrder = ids
        let updatedMetaData = try JSONSerialization.data(
            withJSONObject: imageOrder, options: .prettyPrinted)
        try updatedMetaData.write(to: metaPath)
    }
}
