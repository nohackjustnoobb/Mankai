//
//  ChaptersModal.swift
//  mankai
//
//  Created by Travis XU on 30/6/2025.
//

import SwiftUI

struct ChaptersModal: View {
    let manga: DetailedManga
    let chapterKey: String
    let chapters: [Chapter]

    @Environment(\.dismiss) var dismiss
    @State private var isReversed = true

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(isReversed ? chapters.reversed() : chapters, id: \.id) { chapter in
                        NavigationLink(destination: {}) {
                            Text(chapter.title ?? chapter.id ?? "nil")
                        }
                    }
                } header: {
                    Spacer(minLength: 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isReversed.toggle()
                    }) {
                        Image(
                            systemName: isReversed
                                ? "arrow.counterclockwise"
                                : "arrow.clockwise")
                    }
                }

                ToolbarItem(placement: .principal) {
                    VStack {
                        Text(LocalizedStringKey(chapterKey))
                            .font(.headline)
                        Text("\(chapters.count) chapters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }
}
