//
//  PluginService.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import CoreData
import Foundation

class PluginService: ObservableObject {
    static let shared = PluginService()

    private init() {
        _plugins[AppDirPlugin.shared.id] = AppDirPlugin.shared

        loadJsPluginsFromCoreData()
    }

    private var _plugins: [String: Plugin] = [:]

    var plugins: [Plugin] {
        return Array(_plugins.values)
    }

    private func loadJsPluginsFromCoreData() {
        let jsPlugins = JsPlugin.loadPlugins()

        for jsPlugin in jsPlugins {
            _plugins[jsPlugin.id] = jsPlugin
        }
    }

    func getPlugin(_ id: String) -> Plugin? {
        return _plugins[id]
    }

    func addPlugin(_ plugin: Plugin) throws {
        _plugins[plugin.id] = plugin

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        try plugin.savePlugin()
    }

    func removePlugin(_ id: String) throws {
        if let plugin = _plugins.removeValue(forKey: id) {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            try plugin.deletePlugin()
        }
    }
}
