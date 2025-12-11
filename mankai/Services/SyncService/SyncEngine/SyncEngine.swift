//
//  SyncEngine.swift
//  mankai
//
//  Created by Travis XU on 21/7/2025.
//

import Foundation

class SyncEngine: Identifiable, ObservableObject, Hashable {
    static func == (lhs: SyncEngine, rhs: SyncEngine) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var id: String {
        fatalError("Not Implemented")
    }

    var name: String {
        fatalError("Not Implemented")
    }

    var active: Bool {
        fatalError("Not Implemented")
    }

    func getSavedsHash() async throws -> String {
        fatalError("Not Implemented")
    }

    func getLatestSaved() async throws -> SavedModel? {
        fatalError("Not Implemented")
    }

    func saveSaveds(_: [SavedModel]) async throws {
        fatalError("Not Implemented")
    }

    func updateSaveds(_: [SavedModel]) async throws {
        fatalError("Not Implemented")
    }

    func getLatestRecord() async throws -> RecordModel? {
        fatalError("Not Implemented")
    }

    func updateRecords(_: [RecordModel]) async throws {
        fatalError("Not Implemented")
    }

    func getSaveds(_: Date? = nil) async throws -> [SavedModel] {
        fatalError("Not Implemented")
    }

    func getRecords(_: Date? = nil) async throws -> [RecordModel] {
        fatalError("Not Implemented")
    }
}
