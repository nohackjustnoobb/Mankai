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
        Logger.pluginService.debug("Initializing PluginService")
        _plugins[AppDirPlugin.shared.id] = AppDirPlugin.shared

        loadJsPluginsFromCoreData()
    }

    private var _plugins: [String: Plugin] = [:]

    var plugins: [Plugin] {
        return Array(_plugins.values)
    }

    private func loadJsPluginsFromCoreData() {
        Logger.pluginService.debug("Loading JS plugins from CoreData")
        let jsPlugins = JsPlugin.loadPlugins()
        Logger.pluginService.info("Loaded \(jsPlugins.count) JS plugins")

        for jsPlugin in jsPlugins {
            _plugins[jsPlugin.id] = jsPlugin
        }
    }

    func getPlugin(_ id: String) -> Plugin? {
        return _plugins[id]
    }

    func addPlugin(_ plugin: Plugin) throws {
        Logger.pluginService.debug("Adding plugin: \(plugin.id)")
        _plugins[plugin.id] = plugin

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }

        do {
            try plugin.savePlugin()
            Logger.pluginService.info("Plugin added successfully: \(plugin.id)")
        } catch {
            Logger.pluginService.error("Failed to save plugin: \(plugin.id)", error: error)
            throw error
        }
    }

    func removePlugin(_ id: String) throws {
        Logger.pluginService.debug("Removing plugin: \(id)")
        if let plugin = _plugins.removeValue(forKey: id) {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            do {
                try plugin.deletePlugin()
                Logger.pluginService.info("Plugin removed successfully: \(id)")
            } catch {
                Logger.pluginService.error("Failed to delete plugin: \(id)", error: error)
                throw error
            }
        } else {
            Logger.pluginService.warning("Plugin not found for removal: \(id)")
        }
    }
}
