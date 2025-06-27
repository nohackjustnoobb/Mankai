//
//  PluginGetListScreen.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

struct PluginGetListScreen: View {
    let plugin: Plugin

    var body: some View {
        Group {}
            .navigationTitle(plugin.name ?? plugin.id)
            .navigationBarTitleDisplayMode(.inline)
    }
}
