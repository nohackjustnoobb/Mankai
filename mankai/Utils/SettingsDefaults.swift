//
//  SettingsDefaults.swift
//  mankai
//
//  Created by Travis XU on 29/1/2026.
//

import Foundation

enum SettingsDefaults {
    static let inMemoryCacheExpiryDuration: Double = CacheDuration.auto.rawValue
    static let hideBuiltInPlugins: Bool = false
    static let showDebugScreen: Bool = false

    // Default Reader
    static let readerType: ReaderType = .paged

    // Continuous Reader Defaults
    static let CR_imageLayout: ImageLayout = .auto
    static let CR_readingDirection: ReadingDirection = .rightToLeft
    static let CR_tapNavigation: Bool = true
    static let CR_snapToPage: Bool = false
    static let CR_softSnap: Bool = false

    // Paged Reader Defaults
    static let PR_imageLayout: ImageLayout = .auto
    static let PR_navigationOrientation: NavigationOrientation = .vertical
    static let PR_readingDirection: ReadingDirection = .rightToLeft
    static let PR_tapNavigation: Bool = true
    static let PR_tapNavigationBehavior: TapBehavior = .followReadingDirection
}
