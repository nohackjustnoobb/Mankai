//
//  ReaderSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import SwiftUI

struct ReaderSettingsScreen: View {
    @AppStorage(SettingsKey.readerType.rawValue) private var readerTypeRawValue: Int =
        SettingsDefaults.readerType.rawValue

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
                    String(localized: "readerType"),
                    selection: Binding(
                        get: { ReaderType(rawValue: readerTypeRawValue) ?? SettingsDefaults.readerType },
                        set: { readerTypeRawValue = $0.rawValue }
                    )
                ) {
                    Text(String(localized: "continuous")).tag(ReaderType.continuous)
                    Text(String(localized: "paged")).tag(ReaderType.paged)
                }
            }

            if let readerType = ReaderType(rawValue: readerTypeRawValue) {
                switch readerType {
                case .continuous:
                    ContinuousReaderSettingsView()
                case .paged:
                    PagedReaderSettingsView()
                }
            }
        }
    }
}

struct ContinuousReaderSettingsView: View {
    @AppStorage(SettingsKey.CR_imageLayout.rawValue) private var imageLayoutRawValue: Int =
        SettingsDefaults.CR_imageLayout.rawValue
    @AppStorage(SettingsKey.CR_readingDirection.rawValue) private var readingDirectionRawValue: Int =
        SettingsDefaults.CR_readingDirection.rawValue
    @AppStorage(SettingsKey.CR_tapNavigation.rawValue) private var tapNavigation: Bool =
        SettingsDefaults.CR_tapNavigation
    @AppStorage(SettingsKey.CR_snapToPage.rawValue) private var snapToPage: Bool =
        SettingsDefaults.CR_snapToPage
    @AppStorage(SettingsKey.CR_softSnap.rawValue) private var softSnap: Bool =
        SettingsDefaults.CR_softSnap

    var body: some View {
        Section("continuousReaderSettings") {
            Picker(
                "imageLayout",
                selection: Binding(
                    get: { ImageLayout(rawValue: imageLayoutRawValue) ?? SettingsDefaults.CR_imageLayout },
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
                            ?? SettingsDefaults.CR_readingDirection
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

            if snapToPage {
                Toggle(
                    String(localized: "softSnap"),
                    isOn: $softSnap
                )
            }
        }
    }
}

struct PagedReaderSettingsView: View {
    @AppStorage(SettingsKey.PR_imageLayout.rawValue) private var imageLayoutRawValue: Int =
        SettingsDefaults.PR_imageLayout.rawValue
    @AppStorage(SettingsKey.PR_readingDirection.rawValue) private var readingDirectionRawValue: Int =
        SettingsDefaults.PR_readingDirection.rawValue
    @AppStorage(SettingsKey.PR_navigationOrientation.rawValue) private var navigationOrientationRawValue: Int =
        SettingsDefaults.PR_navigationOrientation.rawValue
    @AppStorage(SettingsKey.PR_tapNavigation.rawValue) private var tapNavigation: Bool =
        SettingsDefaults.PR_tapNavigation
    @AppStorage(SettingsKey.PR_tapNavigationBehavior.rawValue) private var tapNavigationBehaviorRawValue: Int =
        SettingsDefaults.PR_tapNavigationBehavior.rawValue

    private var isVertical: Bool {
        NavigationOrientation(rawValue: navigationOrientationRawValue) == .vertical
    }

    var body: some View {
        Section("pagedReaderSettings") {
            Picker(
                "imageLayout",
                selection: Binding(
                    get: { ImageLayout(rawValue: imageLayoutRawValue) ?? SettingsDefaults.PR_imageLayout },
                    set: { imageLayoutRawValue = $0.rawValue }
                )
            ) {
                Text("auto").tag(ImageLayout.auto)
                Text("onePerRow").tag(ImageLayout.onePerRow)
                Text("twoPerRow").tag(ImageLayout.twoPerRow)
            }

            Picker(
                "navigationOrientation",
                selection: Binding(
                    get: {
                        NavigationOrientation(rawValue: navigationOrientationRawValue)
                            ?? SettingsDefaults.PR_navigationOrientation
                    },
                    set: { navigationOrientationRawValue = $0.rawValue }
                )
            ) {
                Text("horizontal").tag(NavigationOrientation.horizontal)
                Text("vertical").tag(NavigationOrientation.vertical)
            }

            Picker(
                "readingDirection",
                selection: Binding(
                    get: {
                        ReadingDirection(rawValue: readingDirectionRawValue)
                            ?? SettingsDefaults.PR_readingDirection
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

            if tapNavigation && !isVertical {
                Picker(
                    "tapNavigationBehavior",
                    selection: Binding(
                        get: {
                            TapBehavior(rawValue: tapNavigationBehaviorRawValue)
                                ?? SettingsDefaults.PR_tapNavigationBehavior
                        },
                        set: { tapNavigationBehaviorRawValue = $0.rawValue }
                    )
                ) {
                    Text("previousNext").tag(TapBehavior.previousNext)
                    Text("followReadingDirection").tag(TapBehavior.followReadingDirection)
                }
            }
        }
    }
}
