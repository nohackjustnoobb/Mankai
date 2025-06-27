//
//  MangasRowListView.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

struct MangasRowListView: View {
    let mangas: [Manga]
    let pluginId: String
    var query: String? = nil

    @EnvironmentObject var appState: AppState
    @State var plugin: Plugin? = nil

    var body: some View {
        Group {
            VStack(alignment: .leading) {
                NavigationLink(destination: {
                    if let plugin = plugin {
                        if let query = query {
                            PluginSearchScreen(plugin: plugin, query: query)
                        } else {
                            PluginGetListScreen(plugin: plugin)
                        }
                    }

                }) {
                    HStack(spacing: 4) {
                        Text(plugin?.name ?? pluginId)
                            .font(.title3)
                            .foregroundColor(.primary)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    if let plugin = plugin {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(mangas) { manga in
                                Button(action: {
                                    // TODO: manga detail screen
                                    print(manga.title ?? manga.id)
                                }) {
                                    MangaItemView(manga: manga, plugin: plugin)
                                        .aspectRatio(3 / 5, contentMode: .fit)
                                }
                            }
                        }
                    }
                }
                .frame(minHeight: 160)
            }
            .padding()
        }
        .onAppear {
            plugin = appState.pluginService.getPlugin(pluginId)
        }
    }
}
