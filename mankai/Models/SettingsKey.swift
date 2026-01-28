//
//  SettingsKey.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import Foundation

enum SettingsKey: String {
    case inMemoryCacheExpiryDuration
    case imageLayout
    case readingDirection
    case tapNavigation
    case snapToPage
    case softSnap
}

enum ImageLayout: Int {
    case auto = 1
    case onePerRow = 2
    case twoPerRow = 3
}

enum ReadingDirection: Int {
    case leftToRight = 1
    case rightToLeft = 2
}

enum CacheDuration: Double {
    case auto = 0 // Use default
    case fifteenMinutes = 900 // 15 minutes
    case thirtyMinutes = 1800 // 30 minutes
    case oneHour = 3600 // 1 hour
    case twoHours = 7200 // 2 hours
    case sixHours = 21600 // 6 hours
    case twelveHours = 43200 // 12 hours
    case oneDay = 86400 // 24 hours
}
