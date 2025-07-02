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

    func update(_ manga: DetailedManga) async throws {
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

            await MainActor.run {
                objectWillChange.send()
            }
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

        let existingFiles = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
        let imageFiles = existingFiles.compactMap { fileName -> (Int, String)? in
            let fileURL = URL(fileURLWithPath: fileName)
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            guard let number = Int(nameWithoutExtension) else { return nil }
            return (number, fileName)
        }.sorted { $0.0 < $1.0 }

        let startNumber = imageFiles.count

        for (index, imageData) in images.enumerated() {
            let imageNumber = startNumber + index
            let imageFormat = NSData(data: imageData).imageFormat
            let imagePath = chapterPath.appendingPathComponent(
                "\(imageNumber).\(imageFormat.rawValue)")
            try imageData.write(to: imagePath)
        }
    }

    func removeImages(mangaId: String, chapterId: String, images: [UInt]) async throws {
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

        let existingFiles = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
        let imageFiles = existingFiles.compactMap { fileName -> (Int, String)? in
            let fileURL = URL(fileURLWithPath: fileName)
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            guard let number = Int(nameWithoutExtension) else { return nil }
            return (number, fileName)
        }.sorted { $0.0 < $1.0 }

        for index in images {
            guard index < imageFiles.count else { continue }
            let (_, fileName) = imageFiles[Int(index)]
            let imagePath = chapterPath.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: imagePath.path) {
                try fileManager.removeItem(at: imagePath)
            }
        }

        let remainingFiles = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
        let remainingImageFiles = remainingFiles.compactMap { fileName -> (Int, String)? in
            let fileURL = URL(fileURLWithPath: fileName)
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            guard let number = Int(nameWithoutExtension) else { return nil }
            return (number, fileName)
        }.sorted { $0.0 < $1.0 }

        for (newIndex, (_, oldFileName)) in remainingImageFiles.enumerated() {
            let oldPath = chapterPath.appendingPathComponent(oldFileName)
            let fileURL = URL(fileURLWithPath: oldFileName)
            let fileExtension = fileURL.pathExtension
            let newFileName = "\(newIndex).\(fileExtension)"

            if oldFileName != newFileName {
                let newPath = chapterPath.appendingPathComponent(newFileName)
                try fileManager.moveItem(at: oldPath, to: newPath)
            }
        }
    }

    func arrangeImageOrder(mangaId: String, chapterId: String, orders: [UInt]) async throws {
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

        let existingFiles = try fileManager.contentsOfDirectory(atPath: chapterPath.path)
        let imageFiles = existingFiles.compactMap { fileName -> (Int, String)? in
            let fileURL = URL(fileURLWithPath: fileName)
            let nameWithoutExtension = fileURL.deletingPathExtension().lastPathComponent
            guard let number = Int(nameWithoutExtension) else { return nil }
            return (number, fileName)
        }.sorted { $0.0 < $1.0 }

        guard orders.count == imageFiles.count else {
            throw NSError(
                domain: "FsPlugin", code: 400,
                userInfo: [NSLocalizedDescriptionKey: "ordersCountMismatch"])
        }

        let tempPath = chapterPath.appendingPathComponent("temp_reorder")
        try fileManager.createDirectory(
            at: tempPath, withIntermediateDirectories: false, attributes: nil)

        for (newIndex, originalIndex) in orders.enumerated() {
            guard originalIndex < imageFiles.count else { continue }

            let (_, originalFileName) = imageFiles[Int(originalIndex)]
            let originalFilePath = chapterPath.appendingPathComponent(originalFileName)
            let fileURL = URL(fileURLWithPath: originalFileName)
            let fileExtension = fileURL.pathExtension
            let tempFilePath = tempPath.appendingPathComponent("\(newIndex).\(fileExtension)")

            try fileManager.moveItem(at: originalFilePath, to: tempFilePath)
        }

        let tempFiles = try fileManager.contentsOfDirectory(atPath: tempPath.path)
        for tempFileName in tempFiles {
            let tempFilePath = tempPath.appendingPathComponent(tempFileName)
            let finalFilePath = chapterPath.appendingPathComponent(tempFileName)
            try fileManager.moveItem(at: tempFilePath, to: finalFilePath)
        }

        try fileManager.removeItem(at: tempPath)
    }
}
