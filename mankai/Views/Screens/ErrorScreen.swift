//
//  ErrorScreen.swift
//  mankai
//
//  Created by Travis XU on 13/7/2025.
//

import SwiftUI

struct ErrorScreen: View {
    var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.title)

            VStack(spacing: 8) {
                Text("somethingWentWrong")
                    .font(.headline)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("anUnknownErrorOccurred")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("error")
        .navigationBarTitleDisplayMode(.inline)
    }
}
