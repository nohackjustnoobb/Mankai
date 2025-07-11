//
//  ReaderSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import SwiftUI

struct ReaderSettingsScreen: View {
    @AppStorage(SettingsKey.imageLayout.rawValue) private var imageLayoutRawValue: Int = ImageLayout
        .auto.rawValue
    @AppStorage(SettingsKey.readingDirection.rawValue) private var readingDirectionRawValue: Int =
        ReaderScreenConstants.defaultReadingDirection.rawValue

    var body: some View {
        List {
            SettingsHeaderView(
                image: Image(systemName: "book.pages.fill"),
                color: .orange,
                title: String(localized: "reader"),
                description: String(localized: "readerDescription")
            )

            Section {
                Picker(
                    "imageLayout",
                    selection: Binding(
                        get: { ImageLayout(rawValue: imageLayoutRawValue) ?? .auto },
                        set: { imageLayoutRawValue = $0.rawValue }
                    )
                ) {
                    Text("auto").tag(ImageLayout.auto)
                    Text("onePerRow").tag(ImageLayout.onePerRow)
                    Text("twoPerRow").tag(ImageLayout.twoPerRow)
                }

                Picker(
                    "readingDirection",
                    selection: Binding(
                        get: {
                            ReadingDirection(rawValue: readingDirectionRawValue)
                                ?? ReaderScreenConstants.defaultReadingDirection
                        },
                        set: { readingDirectionRawValue = $0.rawValue }
                    )
                ) {
                    Text("leftToRight").tag(ReadingDirection.leftToRight)
                    Text("rightToLeft").tag(ReadingDirection.rightToLeft)
                }
            }
        }
    }
}
