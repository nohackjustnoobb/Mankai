//
//  DebugScreen.swift
//  mankai
//
//  Created by Travis XU on 24/6/2025.
//

import SwiftUI

struct DebugScreen: View {
    @State var plugin: JsPlugin?
    @State private var jsonInput: String = ""
    @State private var isError: Bool = false

    var body: some View {
        List {
            if let plugin = plugin {
                Section("info") {
                    LabeledContent("id") {
                        Text(plugin.id)
                    }
                    LabeledContent("name") {
                        Text(plugin.name ?? String(localized: "nil"))
                    }
                    LabeledContent("version") {
                        Text(plugin.version ?? String(localized: "nil"))
                    }
                    LabeledContent("description") {
                        Text(plugin.description ?? String(localized: "nil"))
                    }
                    LabeledContent("authors") {
                        Text(
                            plugin.authors.isEmpty
                                ? String(localized: "nil") : plugin.authors.joined(separator: ", "))
                    }
                    LabeledContent("repository") {
                        Text(plugin.repository ?? String(localized: "nil"))
                    }
                    LabeledContent("updatesUrl") {
                        Text(plugin.updatesUrl ?? String(localized: "nil"))
                    }
                }

                Section("availableGenres") {
                    if plugin.availableGenres.isEmpty {
                        Text("noGenresAvailable")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(plugin.availableGenres, id: \.self) { genre in
                            Text(LocalizedStringKey(genre.rawValue))
                        }
                    }
                }

                Section("configs") {
                    if plugin.configs.isEmpty {
                        Text("noConfig")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(plugin.configs.indices, id: \.self) { index in
                            let config = plugin.configs[index]

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(config.name)
                                        .font(.headline)
                                    Spacer()
                                    SmallTag(
                                        text: NSLocalizedString(config.type.rawValue, comment: ""))
                                }

                                if let description = config.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                HStack {
                                    Text("key")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(config.key)
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                }

                                HStack {
                                    Text("default")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(describing: config.defaultValue))
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                }

                                if let options = config.options {
                                    HStack {
                                        Text("option")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(String(describing: options))
                                            .font(.caption)
                                            .fontDesign(.monospaced)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("methods") {
                    NavigationLink(
                        destination: DebugGetList(plugin: plugin)
                    ) {
                        Text("getList")
                    }
                    NavigationLink(
                        destination: DebugGetList(plugin: plugin)
                    ) {
                        Text("getMangas")
                    }
                    NavigationLink(
                        destination: DebugGetList(plugin: plugin)
                    ) {
                        Text("getDetailedManga")
                    }
                    NavigationLink(
                        destination: DebugGetList(plugin: plugin)
                    ) {
                        Text("getChapter")
                    }
                    NavigationLink(
                        destination: DebugGetList(plugin: plugin)
                    ) {
                        Text("getImage")
                    }
                    NavigationLink(
                        destination: DebugSearchAndGetSuggestionAndIsOnline(plugin: plugin)
                    ) {
                        Text("isOnline")
                    }
                    NavigationLink(
                        destination: DebugSearchAndGetSuggestionAndIsOnline(plugin: plugin)
                    ) {
                        Text("search")
                    }
                    NavigationLink(
                        destination: DebugSearchAndGetSuggestionAndIsOnline(plugin: plugin)
                    ) {
                        Text("getSuggestion")
                    }
                }

            } else {
                Section("plugin") {
                    TextField("json", text: $jsonInput)
                    Button("parse") {
                        plugin = parsePluginFromJson(jsonInput)
                        if plugin == nil {
                            isError = true
                        }
                    }
                    .alert("error", isPresented: $isError) {
                        Button("ok", role: .cancel) {}
                    }
                }

                Section("jsRuntime") {
                    Button("testJs") {
                        Task {
                            // Test LOG
                            let _ = try! await JsRuntime.shared.execute(
                                "console.log('Hello from JS!!!')", from: "DEBUG"
                            )

                            // Test Fetch
                            try! print(
                                await JsRuntime.shared.execute(
                                    "return (await fetch('https://httpbin.org/get',{headers:{\"test-header\":\"is this working?\"}})).json()"
                                ) as Any
                            )
                        }
                    }
                }
            }
        }
        .environment(\.defaultMinListHeaderHeight, 0)
        .navigationTitle("debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func parsePluginFromJson(_ input: String) -> JsPlugin? {
    guard let data = input.data(using: .utf8) else {
        return nil
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return nil
    }

    return JsPlugin.fromJson(json)
}
