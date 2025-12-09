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

enum ImageHeaderData {
    static var PNG: [UInt8] = [0x89]
    static var JPEG: [UInt8] = [0xFF]
    static var GIF: [UInt8] = [0x47]
    static var TIFF_01: [UInt8] = [0x49]
    static var TIFF_02: [UInt8] = [0x4D]
}

enum ImageFormat: String {
    case Unknown = "unknown"
    case PNG = "png"
    case JPEG = "jpg"
    case GIF = "gif"
    case TIFF = "tiff"
}

extension NSData {
    var imageFormat: ImageFormat {
        var buffer = [UInt8](repeating: 0, count: 1)
        getBytes(&buffer, range: NSRange(location: 0, length: 1))
        if buffer == ImageHeaderData.PNG {
            return .PNG
        } else if buffer == ImageHeaderData.JPEG {
            return .JPEG
        } else if buffer == ImageHeaderData.GIF {
            return .GIF
        } else if buffer == ImageHeaderData.TIFF_01 || buffer == ImageHeaderData.TIFF_02 {
            return .TIFF
        } else {
            return .Unknown
        }
    }
}

func Copy<T: Codable>(of object: T) -> T? {
    do {
        let json = try JSONEncoder().encode(object)
        return try JSONDecoder().decode(T.self, from: json)
    } catch {
        print(error)
        return nil
    }
}
