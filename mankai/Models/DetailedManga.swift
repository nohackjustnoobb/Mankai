//
//  DetailedManga.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import Foundation

struct DetailedManga: Identifiable, Codable {
    var id: String
    var title: String?
    var cover: String?
    var status: Status?
    var latestChapter: Chapter?
    var description: String?
    var updatedAt: Date?
    var authors: [String]
    var genres: [Genre]
    var chapters: [String: [Chapter]]

    var meta: String?

    init?(from any: Any) {
        guard let dict = any as? [String: Any],
              let id = dict["id"] as? String
        else {
            return nil
        }

        self.id = id
        self.title = dict["title"] as? String
        self.cover = dict["cover"] as? String
        self.description = dict["description"] as? String
        self.meta = dict["meta"] as? String

        // Parse status
        if let statusValue = dict["status"] {
            switch statusValue {
            case let status as Status:
                self.status = status
            case let statusUInt as UInt:
                self.status = Status(rawValue: statusUInt)
            default:
                self.status = nil
            }
        } else {
            self.status = nil
        }

        if let chapterDict = dict["latestChapter"] as? [String: Any] {
            self.latestChapter = Chapter(
                id: chapterDict["id"] as? String,
                title: chapterDict["title"] as? String
            )
        } else {
            self.latestChapter = nil
        }

        if let updatedAtMilliseconds = dict["updatedAt"] as? Int64 {
            self.updatedAt = Date(
                timeIntervalSince1970: TimeInterval(updatedAtMilliseconds) / 1000.0)
        } else {
            self.updatedAt = nil
        }

        self.authors = dict["authors"] as? [String] ?? []

        // Parse genres
        if let genresValue = dict["genres"] {
            switch genresValue {
            case let genresArray as [Genre]:
                self.genres = genresArray
            case let genresStringArray as [String]:
                self.genres = genresStringArray.compactMap { Genre(rawValue: $0) }
            default:
                self.genres = []
            }
        } else {
            self.genres = []
        }

        if let chaptersDict = dict["chapters"] as? [String: Any] {
            var chapters: [String: [Chapter]] = [:]

            for (key, value) in chaptersDict {
                chapters[key] = []

                for value in value as? [Any] ?? [] {
                    if let chapterDict = value as? [String: Any] {
                        let chapter = Chapter(
                            id: chapterDict["id"] as? String,
                            title: chapterDict["title"] as? String
                        )
                        chapters[key]!.append(chapter)
                    }
                }
            }

            self.chapters = chapters
        } else {
            self.chapters = [:]
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, cover, status, latestChapter, description, updatedAt, authors, genres,
             chapters, meta
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.cover = try container.decodeIfPresent(String.self, forKey: .cover)
        self.status = try container.decodeIfPresent(Status.self, forKey: .status)
        self.latestChapter = try container.decodeIfPresent(Chapter.self, forKey: .latestChapter)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)

        if let updatedAtMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) {
            self.updatedAt = Date(
                timeIntervalSince1970: TimeInterval(updatedAtMilliseconds) / 1000.0)
        } else {
            self.updatedAt = nil
        }

        self.authors = try container.decodeIfPresent([String].self, forKey: .authors) ?? []
        self.genres = try container.decodeIfPresent([Genre].self, forKey: .genres) ?? []
        self.chapters =
            try container.decodeIfPresent([String: [Chapter]].self, forKey: .chapters) ?? [:]

        self.meta = try container.decodeIfPresent(String.self, forKey: .meta)
    }

    init() {
        self.id = UUID().uuidString
        self.authors = []
        self.genres = []
        self.chapters = ["serial": [], "extra": [], "volume": []]
        self.status = .onGoing
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(cover, forKey: .cover)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(latestChapter, forKey: .latestChapter)
        try container.encodeIfPresent(description, forKey: .description)

        if let updatedAt = updatedAt {
            let milliseconds = Int64(updatedAt.timeIntervalSince1970 * 1000)
            try container.encode(milliseconds, forKey: .updatedAt)
        }

        try container.encode(authors, forKey: .authors)
        try container.encode(genres, forKey: .genres)
        try container.encode(chapters, forKey: .chapters)

        try container.encodeIfPresent(meta, forKey: .meta)
    }
}
