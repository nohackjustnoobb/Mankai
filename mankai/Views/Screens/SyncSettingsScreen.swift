//
//  SyncSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 10/12/2025.
//

import SwiftUI

struct SyncSettingsScreen: View {
    @ObservedObject private var syncService = SyncService.shared
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var showErrorAlert = false

    var body: some View {
        List {
            SettingsHeaderView(
                image: Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90"), color: .blue,
                title: String(localized: "sync"),
                description: String(localized: "syncDescription")
            )

            Section {
                Picker("syncEngine", selection: $syncService.engine) {
                    Text("none").tag(nil as SyncEngine?)
                    ForEach(SyncService.engines, id: \.id) { engine in
                        Text(engine.name).tag(engine as SyncEngine?)
                    }
                }
            }

            if let engine = syncService.engine {
                Section("syncStatus") {
                    LabeledContent("status") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(engine.active ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(engine.active ? "active" : "inactive")
                                .foregroundColor(.secondary)
                        }
                    }

                    LabeledContent("lastSyncTime") {
                        if let lastSyncTime = syncService.lastSyncTime {
                            Text(lastSyncTime, style: .relative)
                                .foregroundColor(.secondary)
                        } else {
                            Text("never")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        Task {
                            await performSync()
                        }
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("syncNow")
                        }
                    }
                    .disabled(isSyncing || !engine.active)
                }
            }

            if let engine = syncService.engine {
                if engine is HttpEngine {
                    HttpEngineConfigView()
                }
            }

            if syncService.engine != nil {
                Section {
                    Button(role: .destructive) {
                        Task {
                            await clearSyncCache()
                        }
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            }
                            Text("clearSyncCache")
                        }
                    }
                    .disabled(isSyncing)
                }
            }
        }
        .navigationTitle("sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert("syncFailed", isPresented: $showErrorAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            if let syncError = syncError {
                Text(syncError)
            }
        }
    }

    private func performSync() async {
        isSyncing = true
        syncError = nil

        do {
            try await syncService.sync()
        } catch {
            syncError = error.localizedDescription
            showErrorAlert = true
        }

        isSyncing = false
    }

    private func clearSyncCache() async {
        isSyncing = true
        syncError = nil

        do {
            try await syncService.onEngineChange()
        } catch {
            syncError = error.localizedDescription
            showErrorAlert = true
        }

        isSyncing = false
    }
}

struct HttpEngineConfigView: View {
    @ObservedObject private var httpEngine = HttpEngine.shared
    @State private var serverUrl: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoggingIn = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    @State private var showLogoutConfirmation = false

    var body: some View {
        Section("httpEngineConfig") {
            if httpEngine.username != nil {
                LabeledContent("serverUrl") {
                    Text(serverUrl)
                        .foregroundColor(.secondary)
                }

                LabeledContent("username") {
                    Text(httpEngine.username ?? "")
                        .foregroundColor(.secondary)
                }

                Button(role: .destructive) {
                    showLogoutConfirmation = true
                } label: {
                    Text("logout")
                }
            } else {
                TextField("serverUrl", text: $serverUrl)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .onChange(of: serverUrl) { _, newValue in
                        httpEngine.serverUrl = newValue.isEmpty ? nil : newValue
                    }

                TextField("username", text: $username)
                    .textContentType(.username)
                    .keyboardType(.default)
                    .autocapitalization(.none)

                SecureField("password", text: $password)
                    .textContentType(.password)

                Button {
                    Task {
                        await performLogin()
                    }
                } label: {
                    if isLoggingIn {
                        ProgressView()
                    } else {
                        Text("login")
                    }
                }
                .disabled(username.isEmpty || password.isEmpty || serverUrl.isEmpty || isLoggingIn)
            }
        }
        .onAppear {
            serverUrl = httpEngine.serverUrl ?? ""
            username = httpEngine.username ?? ""
        }
        .alert("loginFailed", isPresented: $showErrorAlert) {
            Button("ok", role: .cancel) {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .confirmationDialog(
            "logoutConfirmationMessage",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("logout", role: .destructive) {
                httpEngine.logout()
                username = ""
                password = ""
            }
            Button("cancel", role: .cancel) {}
        }
    }

    private func performLogin() async {
        isLoggingIn = true

        do {
            try await httpEngine.login(username: username, password: password)
            // Clear password after successful login
            password = ""
            // Update local state to reflect logged-in state
            username = httpEngine.username ?? ""
            serverUrl = httpEngine.serverUrl ?? ""
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }

        isLoggingIn = false
    }
}
