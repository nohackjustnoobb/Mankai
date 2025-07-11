//
//  GeneralSettingsScreen.swift
//  mankai
//
//  Created by Travis XU on 12/7/2025.
//

import SwiftUI

struct GeneralSettingsScreen: View {
    @AppStorage(SettingsKey.cacheExpiryDuration.rawValue) private var cacheExpiryDurationRawValue:
        Double = CacheDuration.auto.rawValue

    var body: some View {
        List {
            Section {
                Picker(
                    "cacheExpiryDuration",
                    selection: Binding(
                        get: { CacheDuration(rawValue: cacheExpiryDurationRawValue) ?? .auto },
                        set: { cacheExpiryDurationRawValue = $0.rawValue }
                    )
                ) {
                    Text("auto").tag(CacheDuration.auto)
                    Text("15m").tag(CacheDuration.fifteenMinutes)
                    Text("30m").tag(CacheDuration.thirtyMinutes)
                    Text("1h").tag(CacheDuration.oneHour)
                    Text("2h").tag(CacheDuration.twoHours)
                    Text("6h").tag(CacheDuration.sixHours)
                    Text("12h").tag(CacheDuration.twelveHours)
                    Text("1d").tag(CacheDuration.oneDay)
                }
            }

            Section("about") {
                LabeledContent("version") {
                    Text(appVersion)
                }

                LabeledContent("license") {
                    Text("MIT License")
                }
            }
        }
        .navigationTitle("general")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        {
            return "\(version) (\(build))"
        } else if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        {
            return version
        } else {
            return String(localized: "nil")
        }
    }
}
