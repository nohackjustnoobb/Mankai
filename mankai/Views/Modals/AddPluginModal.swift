//
//  AddPluginModal.swift
//  mankai
//
//  Created by Travis XU on 22/6/2025.
//

import SwiftUI

struct AddPluginModal: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var useJson = false
    @State private var jsonInput: String = ""
    @State private var urlInput: String = ""

    @State private var showError: Bool = false

    var body: some View {
        NavigationView {
            // TODO: not what i expected but fine for now
            List {
                Section {
                    Toggle(isOn: $useJson) {
                        Text("useJson")
                    }
                    if useJson {
                        TextField("json", text: $jsonInput)
                            .textInputAutocapitalization(.never)
                    } else {
                        TextField("url", text: $urlInput)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("addPlugin")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("cancel")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        action: {
                            Task {
                                let plugin: JsPlugin?

                                if useJson {
                                    plugin = parsePluginFromJson(jsonInput)
                                } else {
                                    plugin = await parsePluginFromUrl(urlInput)
                                }

                                if plugin != nil {
                                    appState.pluginService.addPlugin(plugin!)
                                    dismiss()
                                } else {
                                    showError = true
                                }
                            }
                        }
                    ) {
                        Text("add").fontWeight(.semibold)
                    }
                    .disabled(useJson ? jsonInput.isEmpty : urlInput.isEmpty)
                }
            }
            .alert("error", isPresented: $showError) {
                Button("ok", role: .cancel) {}
            } message: {
                Text("failedToAddPlugin")
            }
        }
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

private func parsePluginFromUrl(_ urlString: String) async -> JsPlugin? {
    guard let url = URL(string: urlString) else {
        return nil
    }

    return await JsPlugin.fromUrl(url)
}
