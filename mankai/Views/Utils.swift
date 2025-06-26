//
//  Utils.swift
//  mankai
//
//  Created by Travis XU on 25/6/2025.
//

import SwiftUI

struct ColorfulIconLabelStyle: LabelStyle {
    var color: Color
    var size: CGFloat = 1

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            configuration.icon
                .imageScale(.small)
                .foregroundColor(.white)
                .background(RoundedRectangle(cornerRadius: 7 * size).frame(width: 28 * size, height: 28 * size).foregroundColor(color))
        }
    }
}
