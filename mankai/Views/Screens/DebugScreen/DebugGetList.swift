//
//  DebugGetList.swift
//  mankai
//
//  Created by Travis XU on 25/6/2025.
//

import SwiftUI

struct DebugGetList: View {
    let plugin: JsPlugin

    @State var mangas: [Manga]? = nil

    var body: some View {
        Group {
            if let mangas = mangas {
                List {
                    DebugMangas(mangas: mangas, plugin: plugin)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            mangas = try! await plugin.getList(page: 1, genre: Genre.all, status: Status.any)
            Logger.jsPlugin.debug("mangas: \(mangas ?? [])")
        }
    }
}
