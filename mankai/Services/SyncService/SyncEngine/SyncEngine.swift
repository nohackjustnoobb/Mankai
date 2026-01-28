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

    func sync() async throws {
        fatalError("Not Implemented")
    }

    func onSelected() async throws {
        fatalError("Not Implemented")
    }

    func saveSaveds(_: [SavedModel]) async throws {
        fatalError("Not Implemented")
    }
}
