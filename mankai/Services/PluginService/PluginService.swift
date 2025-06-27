//
//  PluginService.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import CoreData
import Foundation

class PluginService: ObservableObject {
    private var _plugins: [String: Plugin] = [:]

    var plugins: [Plugin] {
        return Array(_plugins.values)
    }

    init() {
        loadJsPluginsFromCoreData()
    }

    private func loadJsPluginsFromCoreData() {
        let context = DbService.shared.getContext()
        let request: NSFetchRequest<JsPluginData> = JsPluginData.fetchRequest()

        do {
            let jsPluginDataArray = try context.fetch(request)

            for jsPluginData in jsPluginDataArray {
                if let jsPlugin = JsPlugin.fromDataModel(jsPluginData) {
                    _plugins[jsPlugin.id] = jsPlugin
                }
            }
        } catch {
            print("Failed to load plugins from Core Data: \(error)")
        }
    }

    func getPlugin(_ id: String) -> Plugin? {
        return _plugins[id]
    }

    func addPlugin(_ plugin: Plugin) throws {
        _plugins[plugin.id] = plugin

        objectWillChange.send()

        try plugin.savePlugin()
    }

    func removePlugin(_ id: String) throws {
        if let plugin = _plugins.removeValue(forKey: id) {
            objectWillChange.send()

            try plugin.deletePlugin()
        }
    }
}
