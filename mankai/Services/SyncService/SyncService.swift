//
//  SyncService.swift
//  mankai
//
//  Created by Travis XU on 20/7/2025.
//

import Foundation

class SyncService: ObservableObject {
    static let shared = SyncService()

    private init() {}

    private var _engine: SyncEngine?

    var engine: SyncEngine? {
        get {
            _engine
        }
        set {
            _engine = newValue
            objectWillChange.send()
        }
    }

    func sync() throws {}
}
