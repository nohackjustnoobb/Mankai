//
//  Utils.swift
//  mankai
//
//  Created by Travis XU on 27/6/2025.
//

import SwiftUI

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

extension UIDevice {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
}

extension View {
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}
