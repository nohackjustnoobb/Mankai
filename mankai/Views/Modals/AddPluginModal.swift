//
//  AddPluginModal.swift
//  mankai
//
//  Created by Travis XU on 22/6/2025.
//

import SwiftUI

struct AddPluginModal: View {
    @Environment(\.dismiss) var dismiss

    @State private var useJson = false
    @State private var jsonInput: String = ""
    @State private var urlInput: String = ""

    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isProcessing: Bool = false

    var body: some View {
        NavigationView {
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
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("cancel")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(
                        action: {
                            Task {
                                isProcessing = true
                                defer { isProcessing = false }

                                let plugin: JsPlugin?

                                if useJson {
                                    plugin = parsePluginFromJson(jsonInput)
                                } else {
                                    plugin = await parsePluginFromUrl(urlInput)
                                }

                                guard let plugin = plugin else {
                                    errorMessage = String(localized: "failedToParsePlugin")
                                    showError = true
                                    return
                                }

                                do {
                                    try PluginService.shared.addPlugin(plugin)
                                    dismiss()
                                } catch {
                                    errorMessage =
                                        error.localizedDescription
                                    showError = true
                                }
                            }
                        }
                    ) {
                        if isProcessing {
                            ProgressView()
                        } else {
                            Text("add")
                        }
                    }
                    .disabled(isProcessing || (useJson ? jsonInput.isEmpty : urlInput.isEmpty))
                }
            }
            .alert("failedToAddPlugin", isPresented: $showError) {
                Button("ok", role: .cancel) {}
            } message: {
                Text(errorMessage)
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
