//
//  AppDirPlugin.swift
//  mankai
//
//  Created by Travis XU on 1/7/2025.
//

import Foundation

class AppDirPlugin: ReadWriteFsPlugin {
    static var shared = AppDirPlugin()

    private init() {
        let fileManager = FileManager.default
        let mangaDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("mangas")

        if !fileManager.fileExists(atPath: mangaDir.path) {
            try! fileManager.createDirectory(at: mangaDir, withIntermediateDirectories: true)
        }

        print("AppDirPlugin initialized with PATH: \(mangaDir.path())")

        super.init(mangaDir.path())
    }

    override var id: String {
        "mankai"
    }

    override var tag: String? {
        String(localized: "builtin")
    }

    override var description: String? {
        String(localized: "appFsPluginDescription")
    }

    override var name: String? {
        String(localized: "appName")
    }
}
