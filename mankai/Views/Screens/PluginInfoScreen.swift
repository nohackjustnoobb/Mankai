//
//  PluginInfoScreen.swift
//  mankai
//
//  Created by Travis XU on 26/6/2025.
//

import Combine
import SwiftUI
import WrappingHStack

struct PluginInfoScreen: View {
    @EnvironmentObject var state: AppState
    @ObservedObject var plugin: Plugin

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @State private var showResetConfirmation = false
    @State private var showRemoveConfirmation = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            List {
                Section("info") {
                    LabeledContent("id") {
                        Text(plugin.id)
                    }

                    if let name = plugin.name {
                        LabeledContent("name") {
                            Text(name)
                        }
                    }

                    if let version = plugin.version {
                        LabeledContent("version") {
                            Text(version)
                        }
                    }

                    if let description = plugin.description {
                        LabeledContent("description") {
                            Text(description)
                        }
                    }

                    if !plugin.authors.isEmpty {
                        LabeledContent("authors") {
                            Text(plugin.authors.joined(separator: ", "))
                        }
                    }

                    if let repository = plugin.repository {
                        LabeledContent("repository") {
                            Text(repository)
                        }
                    }

                    if let updatesUrl = plugin.updatesUrl {
                        LabeledContent("updatesUrl") {
                            Text(updatesUrl)
                        }
                    }

                    if plugin.availableGenres.isEmpty {
                        LabeledContent("availableGenres") {
                            Text("noGenresAvailable")
                                .italic()
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("availableGenres")
                            WrappingHStack(plugin.availableGenres, id: \.self, lineSpacing: 8) { genre in
                                Text(LocalizedStringKey(genre.rawValue))
                                    .genreTagStyle()
                            }
                        }
                    }
                }

                if !plugin.configs.isEmpty {
                    Section("configs") {
                        ForEach(plugin.configs, id: \.key) { config in
                            switch config.type {
                            case .text:
                                TextConfigView(plugin: plugin, config: config)
                            case .number:
                                NumberConfigView(plugin: plugin, config: config)
                            case .boolean:
                                BooleanConfigView(plugin: plugin, config: config)
                            case .select:
                                SelectConfigView(plugin: plugin, config: config)
                            }
                        }
                    }
                }

                Section("actions") {
                    if !plugin.configs.isEmpty {
                        Button(
                            "resetConfigs",
                            role: .destructive,
                            action: {
                                showResetConfirmation = true
                            }
                        )
                    }
                    Button(
                        "removePlugin",
                        role: .destructive,
                        action: {
                            showRemoveConfirmation = true
                        }
                    )
                }
            }
        }
        .navigationTitle(plugin.name ?? plugin.id)
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
        .confirmationDialog(
            "resetConfigs", isPresented: $showResetConfirmation, titleVisibility: .visible
        ) {
            Button("reset", role: .destructive) {
                do {
                    try plugin.resetConfigs()
                } catch {
                    errorMessage =
                        String(localized: "failedToResetConfigs") + ": "
                            + error.localizedDescription
                    showErrorAlert = true
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("resetConfigsConfirmation")
        }
        .confirmationDialog(
            "removePlugin", isPresented: $showRemoveConfirmation, titleVisibility: .visible
        ) {
            Button("remove", role: .destructive) {
                do {
                    try state.pluginService.removePlugin(plugin.id)
                    dismiss()
                } catch {
                    errorMessage =
                        String(localized: "failedToRemovePlugin") + ": "
                            + error.localizedDescription
                    showErrorAlert = true
                }
            }
            Button("cancel", role: .cancel) {}
        } message: {
            Text("removePluginConfirmation")
        }
    }
}

struct ConfigTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
            )
            .foregroundColor(.primary)
    }
}

struct TextConfigView: View {
    @ObservedObject var plugin: Plugin
    let config: Config

    @State private var textValue: String = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading) {
                Text(config.name)

                if let description = config.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField(LocalizedStringKey(config.type.rawValue), text: $textValue)
                .textFieldStyle(ConfigTextFieldStyle())
                .onAppear {
                    updateTextValue()
                }
                .onReceive(plugin.objectWillChange) {
                    updateTextValue()
                }
                .onChange(of: textValue, initial: false) { _, newValue in
                    do {
                        try plugin.setConfig(key: config.key, value: newValue)
                    } catch {
                        errorMessage =
                            String(localized: "failedToSetConfigValue") + ": "
                                + error.localizedDescription
                        showErrorAlert = true
                    }
                }
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func updateTextValue() {
        let newValue =
            plugin.getConfig(config.key) as? String ?? config.defaultValue as? String ?? ""
        if textValue != newValue {
            textValue = newValue
        }
    }
}

struct NumberConfigView: View {
    @ObservedObject var plugin: Plugin
    let config: Config

    @State private var numberValue: Double = 0
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading) {
                Text(config.name)

                if let description = config.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField(
                LocalizedStringKey(config.type.rawValue), value: $numberValue, format: .number
            )
            .textFieldStyle(ConfigTextFieldStyle())
            .keyboardType(.decimalPad)
            .onAppear {
                updateNumberValue()
            }
            .onReceive(plugin.objectWillChange) {
                updateNumberValue()
            }
            .onChange(of: numberValue, initial: false) { _, newValue in
                do {
                    try plugin.setConfig(key: config.key, value: newValue)
                } catch {
                    errorMessage =
                        String(localized: "failedToSetConfigValue") + ": "
                            + error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func updateNumberValue() {
        var newValue: Double = 0
        if let value = plugin.getConfig(config.key) as? Double {
            newValue = value
        } else if let value = plugin.getConfig(config.key) as? Int {
            newValue = Double(value)
        } else if let value = config.defaultValue as? Double {
            newValue = value
        } else if let value = config.defaultValue as? Int {
            newValue = Double(value)
        }

        if numberValue != newValue {
            numberValue = newValue
        }
    }
}

struct BooleanConfigView: View {
    @ObservedObject var plugin: Plugin
    let config: Config

    @State private var boolValue: Bool = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        Toggle(isOn: $boolValue) {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.name)
                if let description = config.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            updateBoolValue()
        }
        .onReceive(plugin.objectWillChange) {
            updateBoolValue()
        }
        .onChange(of: boolValue, initial: false) { _, newValue in
            do {
                try plugin.setConfig(key: config.key, value: newValue)
            } catch {
                errorMessage =
                    String(localized: "failedToSetConfigValue") + ": "
                        + error.localizedDescription
                showErrorAlert = true
            }
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func updateBoolValue() {
        let newValue =
            plugin.getConfig(config.key) as? Bool ?? config.defaultValue as? Bool ?? false
        if boolValue != newValue {
            boolValue = newValue
        }
    }
}

struct SelectConfigView: View {
    @ObservedObject var plugin: Plugin
    let config: Config

    @State private var selectedValue: String? = nil
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    private var options: [String] {
        if let optionArray = config.options as? [String] {
            return optionArray
        }

        return []
    }

    var body: some View {
        Group {
            if selectedValue != nil {
                Picker(selection: $selectedValue) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(config.name)
                        if let description = config.description {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedValue, initial: false) { _, newValue in
                    do {
                        if let newValue = newValue {
                            try plugin.setConfig(key: config.key, value: newValue)
                        }
                    } catch {
                        errorMessage =
                            String(localized: "failedToSetConfigValue") + ": "
                                + error.localizedDescription
                        showErrorAlert = true
                    }
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            updateSelectedValue()
        }
        .onReceive(plugin.objectWillChange) {
            updateSelectedValue()
        }
        .alert("error", isPresented: $showErrorAlert) {
            Button("ok") {}
        } message: {
            Text(errorMessage)
        }
    }

    private func updateSelectedValue() {
        var newValue =
            plugin.getConfig(config.key) as? String ?? config.defaultValue as? String ?? ""

        if !options.contains(newValue) && !options.isEmpty {
            newValue = options.first ?? ""
        }

        if selectedValue != newValue {
            selectedValue = newValue
        }
    }
}
