//
//  EditableHttpPlugin.swift
//  mankai
//
//  Created by Travis XU on 11/2/2026.
//

import Foundation

class EditableHttpPlugin: HttpPlugin, Editable {
    override var tags: [String] {
        [String(localized: "http"), String(localized: "editable")]
    }

    // MARK: - Manga Management

    func upsertManga(_ manga: DetailedManga) async throws -> String {
        try await setup()

        var body: [String: Any] = [
            "id": manga.id,
            "authors": manga.authors,
            "genres": manga.genres.map { $0.rawValue },
        ]

        if let title = manga.title {
            body["title"] = title
        }
        if let status = manga.status {
            body["status"] = status.rawValue
        }
        if let description = manga.description {
            body["description"] = description
        }
        if let remarks = manga.remarks {
            body["remarks"] = remarks
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        let (data, _) = try await authManager.post(path: "/edit/manga", body: jsonData)

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        await MainActor.run {
            objectWillChange.send()
        }

        return json?["id"] as? String ?? manga.id
    }

    func deleteManga(_ mangaId: String) async throws {
        try await setup()
        _ = try await authManager.delete(path: "/edit/manga/\(mangaId)")

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func upsertCover(mangaId: String, image: Data) async throws {
        try await setup()

        let contentType = image.detectImageMimeType()
        _ = try await authManager.request(
            method: "POST",
            path: "/edit/manga/\(mangaId)/cover",
            body: image,
            contentType: contentType
        )

        await MainActor.run {
            objectWillChange.send()
        }
    }

    // MARK: - Chapter Group Management

    func upsertChapterGroup(id: String?, mangaId: String, title: String) async throws {
        try await setup()

        var body: [String: Any] = [
            "mangaId": mangaId,
            "title": title,
        ]

        if let id = id {
            body["id"] = id
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        _ = try await authManager.post(path: "/edit/chapter-group", body: jsonData)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteChapterGroup(id: String) async throws {
        try await setup()
        _ = try await authManager.delete(path: "/edit/chapter-group/\(id)")

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func getChapterGroupId(mangaId: String, title: String) async throws -> String? {
        try await setup()

        let (data, _) = try await authManager.get(
            path: "/edit/chapter-group/id",
            query: ["mangaId": mangaId, "title": title]
        )

        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        return json?["id"] as? String
    }

    func getChapters(groupId: String) async throws -> [Chapter] {
        try await setup()

        let (data, _) = try await authManager.get(
            path: "/edit/chapter-group/\(groupId)/chapters"
        )

        return try JSONDecoder().decode([Chapter].self, from: data)
    }

    // MARK: - Chapter Management

    func upsertChapter(id: String?, title: String, chapterGroupId: String) async throws {
        try await setup()

        var body: [String: Any] = [
            "title": title,
            "chapterGroupId": chapterGroupId,
        ]

        if let id = id {
            body["id"] = id
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        _ = try await authManager.post(path: "/edit/chapter", body: jsonData)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteChapter(id: String) async throws {
        try await setup()
        _ = try await authManager.delete(path: "/edit/chapter/\(id)")

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func arrangeChapterOrder(ids: [String]) async throws {
        try await setup()

        let jsonData = try JSONSerialization.data(withJSONObject: ids, options: [])
        _ = try await authManager.post(path: "/edit/chapter/order", body: jsonData)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func addImages(chapterId: String, images: [Data]) async throws {
        try await setup()

        let base64Images = images.map { $0.base64EncodedString() }
        let body: [String: Any] = ["images": base64Images]
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])
        _ = try await authManager.post(
            path: "/edit/chapter/\(chapterId)/images",
            body: jsonData
        )

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func deleteImages(ids: [String]) async throws {
        try await setup()

        let jsonData = try JSONSerialization.data(withJSONObject: ids, options: [])
        _ = try await authManager.post(path: "/edit/images/delete", body: jsonData)

        await MainActor.run {
            objectWillChange.send()
        }
    }

    func arrangeImageOrder(ids: [String]) async throws {
        try await setup()

        let jsonData = try JSONSerialization.data(withJSONObject: ids, options: [])
        _ = try await authManager.post(path: "/edit/images/order", body: jsonData)

        await MainActor.run {
            objectWillChange.send()
        }
    }
}
