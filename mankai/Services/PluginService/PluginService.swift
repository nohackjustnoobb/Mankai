//
//  PluginService.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import Foundation

class PluginService: ObservableObject {
    private var _plugins: [String: Plugin] = [:]

    var plugins: [Plugin] {
        return Array(_plugins.values)
    }

    init() {
        // TODO: Load plugins from the file system
    }

    func getPlugin(byId id: String) -> Plugin? {
        return _plugins[id]
    }

    func addPlugin(_ plugin: Plugin) {
        objectWillChange.send()
        _plugins[plugin.id] = plugin

        // TODO: Save the plugin to the file system
    }

    func removePlugin(byId id: String) {
        objectWillChange.send()
        _plugins.removeValue(forKey: id)

        // TODO: Remove the plugin from the file system
    }
}
