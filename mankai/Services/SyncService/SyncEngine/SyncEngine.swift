//
//  SyncEngine.swift
//  mankai
//
//  Created by Travis XU on 21/7/2025.
//

import Foundation

class SyncEngine {
    var active: Bool {
        fatalError("Not Implemented")
    }

    func getLatestSaved() throws -> SavedModel? {
        fatalError("Not Implemented")
    }

    func getLatestRecord() throws -> RecordModel? {
        fatalError("Not Implemented")
    }

    func saveSaveds(_: [SavedModel]) throws {
        fatalError("Not Implemented")
    }

    func saveRecords(_: [RecordModel]) throws {
        fatalError("Not Implemented")
    }

    func getSaveds(_: Date? = nil) throws -> [SavedModel] {
        fatalError("Not Implemented")
    }

    func getRecords(_: Date? = nil) throws -> [RecordModel] {
        fatalError("Not Implemented")
    }
}
