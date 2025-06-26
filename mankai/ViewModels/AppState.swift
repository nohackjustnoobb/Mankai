//
//  AppState.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

class AppState: ObservableObject {
    @Published var pluginService: PluginService = .init()
}
