//
//  Utils.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

func statusText(_ status: Status?) -> String {
    guard let status = status else { return String(localized: "nil") }
    switch status {
    case .any:
        return String(localized: "any")
    case .onGoing:
        return String(localized: "onGoing")
    case .ended:
        return String(localized: "ended")
    }
}
