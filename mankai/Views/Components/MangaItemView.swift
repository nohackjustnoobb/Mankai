//
//  MangaItemView.swift
//  mankai
//
//  Created by Travis XU on 28/6/2025.
//

import SwiftUI

struct MangaItemView: View {
    let manga: Manga
    let plugin: Plugin

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image
            MangaCoverView(
                coverUrl: manga.cover,
                plugin: plugin,
                tag: manga.status == .ended
                    ? String(localized: "ended") : nil,
                tagColor: .red.opacity(0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack {
                // Title
                if let title = manga.title {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                // Latest Chapter
                if let latestChapter = manga.latestChapter {
                    if let title = latestChapter.title {
                        Text(title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if let id = latestChapter.id {
                        Text("chapter \(id)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
