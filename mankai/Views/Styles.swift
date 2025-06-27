//
//  Styles.swift
//  mankai
//
//  Created by Travis XU on 25/6/2025.
//

import SwiftUI

struct ColorfulIconLabelStyle: LabelStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
        } icon: {
            configuration.icon
                .imageScale(.small)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 7).frame(
                        width: 28, height: 28
                    ).foregroundColor(self.color))
        }
    }
}

struct SmallTagModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(4)
    }
}

extension Text {
    func smallTagStyle() -> some View {
        self.modifier(SmallTagModifier())
    }
}
