//
//  NotificationView.swift
//  mankai
//
//  Created by Travis XU on 21/12/2025.
//

import SwiftUI

struct NotificationView: View {
    let notification: AppNotification
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.system(size: 18, weight: .semibold))

            Text(notification.message)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .applyGlassBackground()
        .padding(.horizontal, 16)
    }

    private var iconName: String {
        switch notification.type {
        case .error:
            return "exclamationmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .error:
            return .red
        case .warning:
            return .orange
        case .success:
            return .green
        case .info:
            return .blue
        }
    }
}

// MARK: - Glass Background Extension

private extension View {
    @ViewBuilder
    func applyGlassBackground() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

struct NotificationContainerView: View {
    @ObservedObject var notificationService = NotificationService.shared
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                Spacer()

                ForEach(notificationService.notifications) { notification in
                    NotificationView(notification: notification) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            notificationService.dismiss(notification.id)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, bottomPadding(for: geometry))
        }
        .animation(
            .spring(response: 0.3, dampingFraction: 0.8), value: notificationService.notifications
        )
        .allowsHitTesting(true)
    }

    private func bottomPadding(for geometry: GeometryProxy) -> CGFloat {
        // On iPad (regular horizontal size class), tab bar is at top, so just use safe area + margin
        if horizontalSizeClass == .regular {
            return max(geometry.safeAreaInsets.bottom, 8)
        }
        // On iPhone (compact), tab bar is at bottom, so add tab bar height
        return max(geometry.safeAreaInsets.bottom, 61)
    }
}
