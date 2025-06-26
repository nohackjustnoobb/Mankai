//
//  Manga.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import Foundation

enum Genre: String, Codable {
    case all
    case action
    case romance
    case yuri
    case boysLove
    case Otokonoko
    case schoolLife
    case adventure
    case harem
    case speculativeFiction
    case war
    case suspense
    case fanFiction
    case comedy
    case magic
    case horror
    case historical
    case sports
    case mature
    case mecha
}

enum Status: UInt, Codable {
    case any = 0
    case onGoing = 1
    case ended = 2
}

struct Chapter: Codable {
    let id: String?
    let title: String?
}

struct Manga: Identifiable, Codable {
    let id: String
    let title: String?
    let cover: String?
    let status: Status?
    let latestChapter: Chapter?
    let meta: String?

    init?(from any: Any) {
        guard let dict = any as? [String: Any],
              let id = dict["id"] as? String
        else {
            return nil
        }

        self.id = id
        self.title = dict["title"] as? String
        self.cover = dict["cover"] as? String
        self.meta = dict["meta"] as? String

        if let statusValue = dict["status"] {
            if let statusUInt = statusValue as? UInt {
                self.status = Status(rawValue: statusUInt)
            } else if let statusString = statusValue as? String,
                      let statusUInt = UInt(statusString)
            {
                self.status = Status(rawValue: statusUInt)
            } else {
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
    }
}
