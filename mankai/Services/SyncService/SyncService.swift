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

    var engine: SyncEngine? {
        get {
            _engine
        }
        set {
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
                try? await onEngineChange()
            }
        }
    }

    var lastSyncTime: Date? {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: "SyncService.lastSyncTime") as? Date
    }

    func onEngineChange() async throws {
        guard let engine = _engine else {
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "noSyncEngine"])
        }

        // Reset last sync time in UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "SyncService.lastSyncTime.records")
        defaults.removeObject(forKey: "SyncService.lastSyncTime.saveds")
        defaults.removeObject(forKey: "SyncService.lastSyncTime")

        // Get hash from remote server
        let remoteHash = try await engine.getSavedsHash()

        // Get local hash
        let localHash = SavedService.shared.generateHash()

        // Compare hashes
        if remoteHash != localHash {
            // Pull saveds from remote
            let remoteSaveds = try await engine.getSaveds()

            // Update local database without deleting existing saveds
            if !remoteSaveds.isEmpty {
                _ = await SavedService.shared.batchUpdate(saveds: remoteSaveds)
            }

            // Push all local saveds to remote
            let localSaveds = SavedService.shared.getAll()
            try await engine.saveSaveds(localSaveds)
        }

        // Call sync
        try await sync()
        try await UpdateService.shared.update()
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
        Task {
            try? await sync()
            try? await UpdateService.shared.update()
        }

        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task {
                try? await self?.sync()
            }
        }

        // Ensure timer runs even when UI is scrolling
        if let timer = syncTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPeriodicSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    deinit {
        stopPeriodicSync()
    }

    func sync() async throws {
        guard let engine = _engine else {
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "noSyncEngine"])
        }

        let defaults = UserDefaults.standard

        // Sync Saveds
        try await syncSaveds(engine: engine, defaults: defaults)

        // Sync Records
        try await syncRecords(engine: engine, defaults: defaults)

        // Update sync time
        defaults.set(Date(), forKey: "SyncService.lastSyncTime")

        await MainActor.run {
            self.objectWillChange.send()
        }
    }

    func pushSaveds() async throws {
        guard let engine = _engine else {
            throw NSError(domain: "SyncService", code: 1, userInfo: [NSLocalizedDescriptionKey: "noSyncEngine"])
        }

        // Get all local saveds
        let localSaveds = SavedService.shared.getAll()

        // Push all saveds to remote
        try await engine.saveSaveds(localSaveds)
    }

    private func syncSaveds(engine: SyncEngine, defaults: UserDefaults) async throws {
        // Get hash from remote server
        let remoteHash = try await engine.getSavedsHash()

        // Get local hash
        let localHash = SavedService.shared.generateHash()

        // Compare hashes
        if remoteHash != localHash {
            // Hashes don't match, pull all saveds from remote
            let remoteSaveds = try await engine.getSaveds()

            // Get all local saveds
            let localSaveds = SavedService.shared.getAll()

            // Create sets for efficient lookup
            let remoteKeys = Set(remoteSaveds.map { "\($0.mangaId)|\($0.pluginId)" })

            // Delete saveds that exist locally but not in remote
            for saved in localSaveds {
                let key = "\(saved.mangaId)|\(saved.pluginId)"
                if !remoteKeys.contains(key) {
                    _ = await SavedService.shared.delete(mangaId: saved.mangaId, pluginId: saved.pluginId)
                }
            }

            // Add or update saveds from remote
            if !remoteSaveds.isEmpty {
                _ = await SavedService.shared.batchUpdate(saveds: remoteSaveds)
            }
        }

        // Get latest saved from remote
        let remoteLatest = try await engine.getLatestSaved()

        // Get latest saved from local
        let localLatest = SavedService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            defaults.set(Date(), forKey: "SyncService.lastSyncTime.saveds")
            return
        }

        // Get last sync time for saveds
        let lastSyncTime = defaults.object(forKey: "SyncService.lastSyncTime.saveds") as? Date

        // Fetch and upload new local saveds since last sync
        if let lastSync = lastSyncTime {
            let newLocalSaveds = SavedService.shared.getAllSince(date: lastSync)
            if !newLocalSaveds.isEmpty {
                try await engine.updateSaveds(newLocalSaveds)
            }
        }

        // Get remote saveds since last sync
        let remoteSavedsUpdates = try await engine.getSaveds(lastSyncTime)

        // Update local database with remote saveds
        if !remoteSavedsUpdates.isEmpty {
            _ = await SavedService.shared.batchUpdate(saveds: remoteSavedsUpdates)
        }

        // Update last sync time for saveds
        defaults.set(Date(), forKey: "SyncService.lastSyncTime.saveds")
    }

    private func syncRecords(engine: SyncEngine, defaults: UserDefaults) async throws {
        // Get latest record from remote
        let remoteLatest = try await engine.getLatestRecord()

        // Get latest record from local
        let localLatest = HistoryService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            defaults.set(Date(), forKey: "SyncService.lastSyncTime.records")
            return
        }

        // Get last sync time
        let lastSyncTime = defaults.object(forKey: "SyncService.lastSyncTime.records") as? Date

        // Fetch and upload new local data since last sync
        if let lastSync = lastSyncTime {
            let newLocalRecords = HistoryService.shared.getAllSince(date: lastSync)
            if !newLocalRecords.isEmpty {
                try await engine.updateRecords(newLocalRecords)
            }
        }

        // Get remote records since last sync
        let remoteRecords = try await engine.getRecords(lastSyncTime)

        // Update local database with remote records
        if !remoteRecords.isEmpty {
            _ = await HistoryService.shared.batchUpdate(records: remoteRecords)
        }

        // Update last sync time
        defaults.set(Date(), forKey: "SyncService.lastSyncTime.records")
    }
}
