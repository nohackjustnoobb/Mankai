//
//  SupabaseEngine.swift
//  mankai
//
//  Created by Travis XU on 1/2/2026.
//

import Foundation
import Supabase

// Realtime is not used here because:
// 1. Even with Realtime, fetching the state is still required to handle data changes that occurred while the app was closed.
// 2. It is rare for users to use multiple devices to read at the exact same time.
// 3. Realtime has a higher cost.
// Therefore, it is not worth it to use Realtime for this use case.
class SupabaseEngine: SyncEngine {
    static let shared = SupabaseEngine()

    private var supabase: SupabaseClient?
    private var _url: String?
    private var _key: String?

    override var id: String {
        return "SupabaseEngine"
    }

    override var name: String {
        return String(localized: "supabaseEngine")
    }

    override var active: Bool {
        return supabase != nil && supabase?.auth.currentUser != nil
    }

    var isConfigured: Bool {
        return supabase != nil
    }

    var currentUrl: String? {
        return _url
    }

    var currentKey: String? {
        return _key
    }

    var currentUser: User? {
        return supabase?.auth.currentUser
    }

    override init() {
        let defaults = UserDefaults.standard
        _url = defaults.string(forKey: "SupabaseEngine.url")
        _key = defaults.string(forKey: "SupabaseEngine.key")

        if let url = _url, let key = _key {
            if let validUrl = URL(string: url) {
                supabase = SupabaseClient(
                    supabaseURL: validUrl,
                    supabaseKey: key,
                    options: SupabaseClientOptions(
                        auth: .init(
                            autoRefreshToken: true,
                            emitLocalSessionAsInitialSession: true
                        )
                    )
                )
            }
        }
    }

    func configClient(url: String, key: String) throws {
        resetClient()

        guard let validUrl = URL(string: url) else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "invalidUrl")])
        }

        _url = url
        _key = key
        supabase = SupabaseClient(
            supabaseURL: validUrl,
            supabaseKey: key,
            options: SupabaseClientOptions(
                auth: .init(
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )

        save()
    }

    func resetClient() {
        if supabase != nil {
            supabase = nil
            _url = nil
            _key = nil

            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: "SupabaseEngine.url")
            defaults.removeObject(forKey: "SupabaseEngine.key")

            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }

    // MARK: - Authentication

    func login(provider: Provider) async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotConfigured")])
        }

        Logger.supabaseEngine.info("Logging in with provider: \(provider)")
        try await supabase.auth.signInWithOAuth(provider: provider, redirectTo: URL(string: "mankai://login-callback")!)

        try? await SyncService.shared.onEngineChange()

        await MainActor.run {
            self.objectWillChange.send()
        }
    }

    func logout() async throws {
        guard let supabase = supabase else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotConfigured")])
        }

        Logger.supabaseEngine.info("Logging out")
        try await supabase.auth.signOut()

        await MainActor.run {
            self.objectWillChange.send()
        }
    }

    func save() {
        let defaults = UserDefaults.standard

        defaults.set(_url, forKey: "SupabaseEngine.url")
        defaults.set(_key, forKey: "SupabaseEngine.key")
    }

    // MARK: - SyncEngine Overrides

    override func onSelected() async throws {
        Logger.supabaseEngine.debug("Selected")

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "SupabaseEngine.lastSyncTime.records")
        defaults.removeObject(forKey: "SupabaseEngine.lastSyncTime.saveds")
    }

    override func sync() async throws {
        Logger.supabaseEngine.debug("Syncing")

        let defaults = UserDefaults.standard

        // Sync Saveds
        try await syncSaveds(defaults: defaults)

        // Sync Records
        try await syncRecords(defaults: defaults)

        Logger.supabaseEngine.debug("Sync completed")
    }

    override func addSaveds(_ saveds: [SavedModel]) async throws {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine adding \(saveds.count) saveds")

        // Optimization: For small batches, fetch only relevant items
        // For larger batches (e.g. initial sync), it's more efficient to fetch everything
        let existingSaveds: [SavedModel]
        if saveds.count <= 20 {
            existingSaveds = try await getSaveds(for: saveds)
        } else {
            existingSaveds = try await getSaveds()
        }

        // Create a map of existing saveds by key for conflict resolution
        let existingMap = Dictionary(
            existingSaveds.map { ("\($0.mangaId)|\($0.pluginId)", $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Filter saveds: only include those with newer datetime than remote
        let savedsToUpsert = saveds.filter { saved in
            let key = "\(saved.mangaId)|\(saved.pluginId)"
            if let existing = existingMap[key] {
                return saved.datetime > existing.datetime
            }
            return true // No conflict, include it
        }

        if savedsToUpsert.isEmpty {
            Logger.supabaseEngine.debug("No saveds to upsert after conflict resolution")
            return
        }

        let supabaseSaveds = savedsToUpsert.map { s in
            SupabaseSaved(
                mangaId: s.mangaId,
                pluginId: s.pluginId,
                userId: userId,
                datetime: s.datetime,
                updates: s.updates,
                latestChapter: s.latestChapter,
                updatedAt: nil
            )
        }

        try await supabase.from("Saved").upsert(supabaseSaveds).execute()
        Logger.supabaseEngine.info("Upserted \(savedsToUpsert.count) saveds")
    }

    private func getSaveds(for items: [SavedModel]) async throws -> [SavedModel] {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        guard !items.isEmpty else { return [] }

        // Build composite key filter
        // Format: or(and(mangaId.eq.m1,pluginId.eq.p1),and(mangaId.eq.m2,pluginId.eq.p2),...)
        let filters = items.map { "and(mangaId.eq.\($0.mangaId),pluginId.eq.\($0.pluginId))" }
        let orFilter = filters.joined(separator: ",")

        let query = supabase.from("Saved")
            .select()
            .eq("userId", value: userId)
            .or(orFilter)

        let chunk: [SupabaseSaved] = try await query.execute().value

        return chunk.map { s in
            SavedModel(
                mangaId: s.mangaId,
                pluginId: s.pluginId,
                datetime: s.datetime,
                updates: s.updates,
                latestChapter: s.latestChapter
            )
        }
    }

    override func removeSaveds(_ saveds: [(mangaId: String, pluginId: String)]) async throws {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        guard !saveds.isEmpty else { return }

        Logger.supabaseEngine.debug("SupabaseEngine removing \(saveds.count) saveds")

        // Delete each saved individually (composite key requires multiple conditions)
        for saved in saveds {
            try await supabase.from("Saved")
                .delete()
                .eq("userId", value: userId)
                .eq("mangaId", value: saved.mangaId)
                .eq("pluginId", value: saved.pluginId)
                .execute()
        }

        Logger.supabaseEngine.info("Removed \(saveds.count) saveds")
    }

    override func initialSync() async throws {
        Logger.supabaseEngine.info("Initial sync")

        let localSaveds = SavedService.shared.getAll()

        try await addSaveds(localSaveds)
    }

    // MARK: - Internal Sync Logic

    private struct SupabaseSaved: Codable {
        let mangaId: String
        let pluginId: String
        let userId: UUID
        let datetime: Date
        let updates: Bool
        let latestChapter: String
        let updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case mangaId
            case pluginId
            case userId
            case datetime
            case updates
            case latestChapter
            case updatedAt
        }
    }

    private func syncSaveds(defaults: UserDefaults) async throws {
        Logger.supabaseEngine.debug("Syncing saveds")

        // TODO: optimize
        // Get remote saved keys to check for deletions (only fetch primary keys)
        let remoteKeys = try await getSavedKeys()

        // Get all local saveds
        let allLocalSaveds = SavedService.shared.getAll()

        // Delete saveds that exist locally but not in remote
        for saved in allLocalSaveds {
            let key = "\(saved.mangaId)|\(saved.pluginId)"
            if !remoteKeys.contains(key) {
                Logger.supabaseEngine.info("Deleting local saved not in remote: \(saved.mangaId)")
                _ = await SavedService.shared.delete(mangaId: saved.mangaId, pluginId: saved.pluginId)
            }
        }

        // Get latest saved from remote
        let remoteLatest = try await getLatestSaved()

        // Get latest saved from local
        let localLatest = SavedService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            Logger.supabaseEngine.debug("Saveds already synced")
            defaults.set(Date(), forKey: "SupabaseEngine.lastSyncTime.saveds")
            return
        }

        // Get last sync time
        let lastSyncTime = defaults.object(forKey: "SupabaseEngine.lastSyncTime.saveds") as? Date

        // 1. Fetch NEW local saveds (updated since last sync)
        let newLocalSaveds = SavedService.shared.getAllSince(date: lastSyncTime)

        // 2. Fetch NEW remote saveds (updated since last sync)
        let remoteSaveds = try await getSaveds(lastSyncTime)

        // 3. Resolve Conflicts
        var savedsToUpload = newLocalSaveds
        var savedsToApply = remoteSaveds

        if !newLocalSaveds.isEmpty, !remoteSaveds.isEmpty {
            // Create maps for efficient lookup
            let remoteMap = Dictionary(grouping: remoteSaveds, by: { "\($0.mangaId)|\($0.pluginId)" })
                .compactMapValues { $0.first }

            // Filter uploads: Only upload if local is newer than remote
            savedsToUpload = newLocalSaveds.filter { local in
                let key = "\(local.mangaId)|\(local.pluginId)"
                if let remote = remoteMap[key] {
                    return local.datetime > remote.datetime
                }
                return true
            }

            // Filter downloads: Only apply if remote is newer than local
            let localMap = Dictionary(grouping: newLocalSaveds, by: { "\($0.mangaId)|\($0.pluginId)" })
                .compactMapValues { $0.first }

            savedsToApply = remoteSaveds.filter { remote in
                let key = "\(remote.mangaId)|\(remote.pluginId)"
                if let local = localMap[key] {
                    return remote.datetime > local.datetime
                }
                return true
            }
        }

        // 4. Upload filtered local saveds
        if !savedsToUpload.isEmpty {
            Logger.supabaseEngine.info("Uploading \(savedsToUpload.count) new local saveds")
            try await updateSaveds(savedsToUpload)
        }

        // 5. Apply filtered remote saveds
        if !savedsToApply.isEmpty {
            Logger.supabaseEngine.info("Downloading \(savedsToApply.count) remote saveds updates")
            _ = await SavedService.shared.batchUpdate(saveds: savedsToApply)
        }

        // Update last sync time
        defaults.set(Date(), forKey: "SupabaseEngine.lastSyncTime.saveds")
    }

    private func getLatestSaved() async throws -> SavedModel? {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine getting latest saved")

        let query = supabase.from("Saved")
            .select()
            .eq("userId", value: userId)
            .order("datetime", ascending: false)
            .limit(1)

        let saveds: [SupabaseSaved] = try await query.execute().value

        guard let first = saveds.first else { return nil }

        return SavedModel(
            mangaId: first.mangaId,
            pluginId: first.pluginId,
            datetime: first.datetime,
            updates: first.updates,
            latestChapter: first.latestChapter
        )
    }

    private func getSavedKeys() async throws -> Set<String> {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine getting saved keys")

        struct SavedKey: Codable {
            let mangaId: String
            let pluginId: String
        }

        var allKeys: Set<String> = []
        var offset = 0
        let limit = 1000

        while true {
            let chunkQuery = supabase.from("Saved")
                .select("mangaId, pluginId")
                .eq("userId", value: userId)
                .range(from: offset, to: offset + limit - 1)

            let chunk: [SavedKey] = try await chunkQuery.execute().value

            for key in chunk {
                allKeys.insert("\(key.mangaId)|\(key.pluginId)")
            }

            if chunk.count < limit {
                break
            }
            offset += limit
        }

        return allKeys
    }

    private func getSaveds(_ since: Date? = nil) async throws -> [SavedModel] {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine getting saveds since: \(String(describing: since))")

        var query = supabase.from("Saved")
            .select()
            .eq("userId", value: userId)

        if let since = since {
            let isoDate = ISO8601DateFormatter().string(from: since)
            query = query.gt("datetime", value: isoDate)
        }

        var allResults: [SavedModel] = []
        var offset = 0
        let limit = 1000

        while true {
            let chunkQuery = query
                .order("datetime", ascending: false)
                .range(from: offset, to: offset + limit - 1)

            let chunk: [SupabaseSaved] = try await chunkQuery.execute().value

            let models = chunk.map { s in
                SavedModel(
                    mangaId: s.mangaId,
                    pluginId: s.pluginId,
                    datetime: s.datetime,
                    updates: s.updates,
                    latestChapter: s.latestChapter
                )
            }

            allResults.append(contentsOf: models)

            if chunk.count < limit {
                break
            }
            offset += limit
        }

        return allResults
    }

    private func updateSaveds(_ saveds: [SavedModel]) async throws {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine updating \(saveds.count) saveds")

        let supabaseSaveds = saveds.map { s in
            SupabaseSaved(
                mangaId: s.mangaId,
                pluginId: s.pluginId,
                userId: userId,
                datetime: s.datetime,
                updates: s.updates,
                latestChapter: s.latestChapter,
                updatedAt: nil // Will be updated by DB
            )
        }

        try await supabase.from("Saved").upsert(supabaseSaveds).execute()
    }

    private struct SupabaseRecord: Codable {
        let mangaId: String
        let pluginId: String
        let userId: UUID
        let datetime: Date
        let chapterId: String?
        let chapterTitle: String?
        let page: Int
        let updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case mangaId
            case pluginId
            case userId
            case datetime
            case chapterId
            case chapterTitle
            case page
            case updatedAt
        }
    }

    private func syncRecords(defaults: UserDefaults) async throws {
        Logger.supabaseEngine.debug("Syncing records")

        // Get latest record from remote
        let remoteLatest = try await getLatestRecord()

        // Get latest record from local
        let localLatest = HistoryService.shared.getLatest()

        // Check if already synced (comparing primary key and datetime)
        if let remote = remoteLatest, let local = localLatest,
           remote.mangaId == local.mangaId,
           remote.pluginId == local.pluginId,
           abs(remote.datetime.timeIntervalSince(local.datetime)) < 1e-3
        {
            // Already synced
            Logger.supabaseEngine.debug("Records already synced")
            defaults.set(Date(), forKey: "SupabaseEngine.lastSyncTime.records")
            return
        }

        // Get last sync time
        let lastSyncTime = defaults.object(forKey: "SupabaseEngine.lastSyncTime.records") as? Date

        // 1. Fetch NEW local records (updated since last sync)
        let newLocalRecords = HistoryService.shared.getAllSince(date: lastSyncTime)

        // 2. Fetch NEW remote records (updated since last sync)
        let remoteRecords = try await getRecords(lastSyncTime)

        // 3. Resolve Conflicts
        // We need to decide:
        // - What to upload (local > remote)
        // - What to download/apply (remote > local)

        var recordsToUpload = newLocalRecords
        var recordsToApply = remoteRecords

        if !newLocalRecords.isEmpty, !remoteRecords.isEmpty {
            // Create maps for efficient lookup
            let remoteMap = Dictionary(grouping: remoteRecords, by: { "\($0.mangaId)|\($0.pluginId)" })
                .compactMapValues { $0.first } // Should be unique per ID

            // Filter uploads: Only upload if local is newer than remote (or remote doesn't exist in conflict set)
            recordsToUpload = newLocalRecords.filter { local in
                let key = "\(local.mangaId)|\(local.pluginId)"
                if let remote = remoteMap[key] {
                    // Conflict found. Keep local if it's newer.
                    return local.datetime > remote.datetime
                }
                // No conflict, safe to upload
                return true
            }

            // Filter downloads: Only apply if remote is newer than local (or local doesn't exist in conflict set)
            let localMap = Dictionary(grouping: newLocalRecords, by: { "\($0.mangaId)|\($0.pluginId)" })
                .compactMapValues { $0.first }

            recordsToApply = remoteRecords.filter { remote in
                let key = "\(remote.mangaId)|\(remote.pluginId)"
                if let local = localMap[key] {
                    // Conflict found. Keep remote if it's newer.
                    return remote.datetime > local.datetime
                }
                // No conflict, safe to apply
                return true
            }
        }

        // 4. Upload filtered local records
        if !recordsToUpload.isEmpty {
            Logger.supabaseEngine.info("Uploading \(recordsToUpload.count) new local records")
            try await updateRecords(recordsToUpload)
        }

        // 5. Apply filtered remote records
        if !recordsToApply.isEmpty {
            Logger.supabaseEngine.info("Downloading \(recordsToApply.count) remote records updates")
            _ = await HistoryService.shared.batchUpdate(records: recordsToApply)
        }

        // Update last sync time
        defaults.set(Date(), forKey: "SupabaseEngine.lastSyncTime.records")
    }

    private func getLatestRecord() async throws -> RecordModel? {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine getting latest record")

        let query = supabase.from("Record")
            .select()
            .eq("userId", value: userId)
            .order("datetime", ascending: false)
            .limit(1)

        let records: [SupabaseRecord] = try await query.execute().value

        guard let first = records.first else { return nil }

        return RecordModel(
            mangaId: first.mangaId,
            pluginId: first.pluginId,
            datetime: first.datetime,
            chapterId: first.chapterId,
            chapterTitle: first.chapterTitle,
            page: first.page
        )
    }

    private func getRecords(_ since: Date? = nil) async throws -> [RecordModel] {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine getting records since: \(String(describing: since))")

        // Supabase/PostgREST uses ISO8601 strings for date comparison
        var query = supabase.from("Record")
            .select() // Select all fields
            .eq("userId", value: userId)

        if let since = since {
            let isoDate = ISO8601DateFormatter().string(from: since)
            query = query.gt("datetime", value: isoDate)
        }

        // Pagination
        var allResults: [RecordModel] = []
        var offset = 0
        let limit = 1000 // max limit 1000

        while true {
            // Apply order and range to the filtered query
            let chunkQuery = query
                .order("datetime", ascending: false)
                .range(from: offset, to: offset + limit - 1)

            let chunk: [SupabaseRecord] = try await chunkQuery.execute().value

            let models = chunk.map { r in
                RecordModel(
                    mangaId: r.mangaId,
                    pluginId: r.pluginId,
                    datetime: r.datetime,
                    chapterId: r.chapterId,
                    chapterTitle: r.chapterTitle,
                    page: r.page
                )
            }

            allResults.append(contentsOf: models)

            if chunk.count < limit {
                break
            }
            offset += limit
        }

        return allResults
    }

    private func updateRecords(_ records: [RecordModel]) async throws {
        guard let supabase = supabase, let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: String(localized: "supabaseNotReady")])
        }

        Logger.supabaseEngine.debug("SupabaseEngine updating \(records.count) records")

        let supabaseRecords = records.map { r in
            SupabaseRecord(
                mangaId: r.mangaId,
                pluginId: r.pluginId,
                userId: userId,
                datetime: r.datetime,
                chapterId: r.chapterId,
                chapterTitle: r.chapterTitle,
                page: r.page,
                updatedAt: nil // Will be updated by DB
            )
        }

        // Upsert allows bulk
        try await supabase.from("Record").upsert(supabaseRecords).execute()
    }
}
