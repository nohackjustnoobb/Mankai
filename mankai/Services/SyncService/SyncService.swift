//
//  SyncService.swift
//  mankai
//
//  Created by Travis XU on 20/7/2025.
//

import Combine
import Foundation
import GRDB

class SyncService: ObservableObject {
    static let shared = SyncService()
    static let engines: [SyncEngine] =
        [HttpEngine.shared]

    private init() {
        Logger.syncService.debug("Initializing SyncService")
        let defaults = UserDefaults.standard
        if let engineId = defaults.string(forKey: "SyncService.engineId") {
            _engine = SyncService.engines.first(where: { $0.id == engineId })
            subscribeToEngine()
            startPeriodicSync()
        }
    }

    private var _engine: SyncEngine?
    private var engineCancellable: AnyCancellable?
    private var syncTimer: Timer?
    private let syncInterval: TimeInterval = 60 // 1 minute

    @Published var isSyncing = false

    var engine: SyncEngine? {
        get {
            _engine
        }
        set {
            Logger.syncService.debug("Setting sync engine: \(newValue?.id ?? "nil")")
            _engine = newValue

            let defaults = UserDefaults.standard
            defaults.setValue(newValue?.id, forKey: "SyncService.engineId")

            subscribeToEngine()

            if newValue != nil {
                startPeriodicSync()
            } else {
                stopPeriodicSync()
            }

            DispatchQueue.main.async {
                self.objectWillChange.send()
            }

            Task {
                try? await self.onEngineChange()
            }
        }
    }

    var lastSyncTime: Date? {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "SyncService.lastSyncTime") as? Date
    }

    func onEngineChange() async throws {
        if isSyncing {
            Logger.syncService.warning("Sync in progress, skipping engine change sync")
            return
        }

        await MainActor.run { isSyncing = true }
        defer {
            Task { @MainActor in isSyncing = false }
        }

        Logger.syncService.debug("Handling engine change")
        guard let engine = _engine else {
            Logger.syncService.error("No sync engine available")
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "noSyncEngine")])
        }

        // Reset last sync time in UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "SyncService.lastSyncTime")

        try await engine.onSelected()
    }

    private func subscribeToEngine() {
        engineCancellable?.cancel()
        engineCancellable = _engine?.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }

    private func startPeriodicSync() {
        stopPeriodicSync()

        guard _engine != nil else { return }

        // Initial
        Logger.syncService.debug("Starting periodic sync")
        Task {
            try? await sync()
            try? await UpdateService.shared.update()
        }

        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.sync()
            }
        }
    }

    private func stopPeriodicSync() {
        Logger.syncService.debug("Stopping periodic sync")
        syncTimer?.invalidate()
        syncTimer = nil
    }

    deinit {
        stopPeriodicSync()
        engineCancellable?.cancel()
    }

    func sync(wait: Bool = false) async throws {
        if isSyncing {
            if !wait {
                Logger.syncService.debug("Sync already in progress, skipping")
                return
            }

            Logger.syncService.debug("Waiting for ongoing sync to complete")
            while isSyncing {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            }
            Logger.syncService.debug("Ongoing sync completed, proceeding")
            return
        }

        await MainActor.run { isSyncing = true }
        defer {
            Task { @MainActor in isSyncing = false }
        }

        try await internalSync()
    }

    private func internalSync() async throws {
        Logger.syncService.debug("Starting sync")
        guard let engine = _engine else {
            Logger.syncService.error("No sync engine available")
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "noSyncEngine")])
        }

        try await engine.sync()

        // Update sync time
        UserDefaults.standard.set(Date(), forKey: "SyncService.lastSyncTime")

        await MainActor.run {
            self.objectWillChange.send()
        }
        Logger.syncService.debug("Sync completed")
    }

    func pushSaveds() async throws {
        Logger.syncService.debug("Pushing saveds")
        guard let engine = _engine else {
            Logger.syncService.error("No sync engine available")
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "noSyncEngine")])
        }

        // Get all local saveds
        let localSaveds = SavedService.shared.getAll()

        // Push all saveds to remote
        try await engine.saveSaveds(localSaveds)
        Logger.syncService.info("Pushed \(localSaveds.count) saveds to remote")
    }
}
