//
//  ReaderScreen.swift
//  mankai
//
//  Created by Travis XU on 30/6/2025.
//

import SwiftUI

struct ReaderScreen: View {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter

    var body: some View {
        Text(chapter.title ?? chapter.id ?? "No title")
    }
}
