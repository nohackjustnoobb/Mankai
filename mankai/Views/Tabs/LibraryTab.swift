//
//  LibraryTab.swift
//  mankai
//
//  Created by Travis XU on 21/6/2025.
//

import SwiftUI

struct LibraryTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        LibraryTabContent(pluginService: appState.pluginService)
    }
}

struct LibraryTabContent: View {
    @ObservedObject var pluginService: PluginService

    var body: some View {
        NavigationView {
            VStack {}.navigationTitle("library")
        }
    }
}
