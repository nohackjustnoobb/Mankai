//
//  ReaderSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import SwiftUI

struct ReaderSettingsScreen: View {
    @AppStorage(SettingsKey.imageLayout.rawValue) private var imageLayoutRawValue: Int = ReaderScreenConstants.defaultImageLayout.rawValue
    @AppStorage(SettingsKey.readingDirection.rawValue) private var readingDirectionRawValue: Int =
        ReaderScreenConstants.defaultReadingDirection.rawValue
    @AppStorage(SettingsKey.tapNavigation.rawValue) private var tapNavigation: Bool =
        ReaderScreenConstants.defaultTapNavigation
    @AppStorage(SettingsKey.snapToPage.rawValue) private var snapToPage: Bool =
        ReaderScreenConstants.defaultSnapToPage
    @AppStorage(SettingsKey.softSnap.rawValue) private var softSnap: Bool =
        ReaderScreenConstants.defaultSoftSnap

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
                        get: { ImageLayout(rawValue: imageLayoutRawValue) ?? ReaderScreenConstants.defaultImageLayout },
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

                Toggle(
                    String(localized: "tapNavigation"),
                    isOn: $tapNavigation
                )

                Toggle(
                    String(localized: "snapToPage"),
                    isOn: $snapToPage
                )

                Toggle(
                    String(localized: "softSnap"),
                    isOn: $softSnap
                )
            }
        }
    }
}
