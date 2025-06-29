//
//  MangasListView.swift
//  mankai
//
//  Created by Travis XU on 28/6/2025.
//

import SwiftUI

struct MangasListView: View {
    let mangas: [Manga]
    let plugin: Plugin

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 110), spacing: 12)
            ], spacing: 12
        ) {
            ForEach(mangas, id: \.id) { manga in
                NavigationLink(
                    destination: MangaDetailsScreen(plugin: plugin, manga: manga)
                ) {
                    MangaItemView(manga: manga, plugin: plugin)
                        .aspectRatio(3 / 5, contentMode: .fit)
                }
            }
        }
    }
}
