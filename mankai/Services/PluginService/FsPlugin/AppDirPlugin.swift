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
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        print("AppDirPlugin initialized with documents URL: \(documentsURL.path())")

        super.init(documentsURL.path())
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
