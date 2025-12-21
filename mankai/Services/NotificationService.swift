//
//  NotificationService.swift
//  mankai
//
//  Created by Travis XU on 21/12/2025.
//

import Foundation
import SwiftUI

enum NotificationType {
    case error
    case warning
    case success
    case info
}

struct AppNotification: Identifiable, Equatable {
    let id = UUID()
    let type: NotificationType
    let message: String
    let duration: TimeInterval

    init(type: NotificationType, message: String, duration: TimeInterval = 5.0) {
        self.type = type
        self.message = message
        self.duration = duration
    }
}

class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var notifications: [AppNotification] = []
    private var dismissTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func show(type: NotificationType, message: String, duration: TimeInterval = 5.0) {
        let notification = AppNotification(type: type, message: message, duration: duration)

        Task { @MainActor in
            notifications.append(notification)

            // Auto dismiss after duration
            let task = Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                dismiss(notification.id)
            }
            dismissTasks[notification.id] = task
        }
    }

    func showError(_ message: String, duration: TimeInterval = 5.0) {
        show(type: .error, message: message, duration: duration)
    }

    func showWarning(_ message: String, duration: TimeInterval = 5.0) {
        show(type: .warning, message: message, duration: duration)
    }

    func showSuccess(_ message: String, duration: TimeInterval = 5.0) {
        show(type: .success, message: message, duration: duration)
    }

    func showInfo(_ message: String, duration: TimeInterval = 5.0) {
        show(type: .info, message: message, duration: duration)
    }

    @MainActor
    func dismiss(_ id: UUID) {
        notifications.removeAll { $0.id == id }
        dismissTasks[id]?.cancel()
        dismissTasks.removeValue(forKey: id)
    }

    @MainActor
    func dismissAll() {
        notifications.removeAll()
        dismissTasks.values.forEach { $0.cancel() }
        dismissTasks.removeAll()
    }
}
