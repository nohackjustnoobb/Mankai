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

    // Reader Defaults
    static let imageLayout: ImageLayout = .auto
    static let readingDirection: ReadingDirection = .rightToLeft
    static let tapNavigation: Bool = true
    static let snapToPage: Bool = false
    static let softSnap: Bool = false
}
