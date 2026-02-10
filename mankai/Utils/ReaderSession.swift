//
//  ReaderSession.swift
//  mankai
//
//  Created by Travis XU on 10/2/2026.
//

import Combine
import SwiftUI
import UIKit

enum ReaderImageState {
    case loading
    case success(UIImage)
    case failed
}

struct ReaderImage {
    let url: String
    var state: ReaderImageState
}

struct ReaderGroup: Identifiable, Hashable {
    let id = UUID()
    var urls: [String]

    func contains(_ url: String) -> Bool {
        return urls.contains(url)
    }
}

class ReaderSession: ObservableObject {
    @Published var images: [String: ReaderImage] = [:]
    @Published var groups: [ReaderGroup] = []
    private(set) var urls: [String] = []

    private let plugin: Plugin
    private let manga: DetailedManga
    @Published var imageLayout: ImageLayout {
        didSet {
            groupImages()
        }
    }

    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private var retryCount: [String: Int] = [:]
    private let maxRetries = 3

    init(plugin: Plugin, manga: DetailedManga, imageLayout: ImageLayout) {
        self.plugin = plugin
        self.manga = manga
        self.imageLayout = imageLayout
    }

    func getChapter(chapter: Chapter) async throws {
        // Cancel all existing loading tasks
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()

        // Reset state
        images = [:]
        groups = []
        urls = []
        retryCount = [:]

        let urls = try await plugin.getChapter(manga: manga, chapter: chapter)
        self.urls = urls

        // Initialize images with loading state
        for url in urls {
            images[url] = ReaderImage(url: url, state: .loading)
        }

        // Initial grouping
        groupImages()

        loadImages(urls: urls)
    }

    private func loadImages(urls: [String]) {
        for url in urls {
            loadImage(url: url)
        }
    }

    private func loadImage(url: String) {
        let task = Task {
            let currentRetry = await MainActor.run { self.retryCount[url] ?? 0 }

            do {
                let imageData = try await plugin.getImage(url)
                if let image = UIImage(data: imageData) {
                    await MainActor.run {
                        self.images[url] = ReaderImage(url: url, state: .success(image))
                        self.groupImages()
                    }
                } else {
                    await self.handleImageLoadFailure(url: url, currentRetry: currentRetry)
                }
            } catch {
                if !Task.isCancelled {
                    await self.handleImageLoadFailure(url: url, currentRetry: currentRetry)
                }
            }
        }

        loadingTasks[url] = task
    }

    private func handleImageLoadFailure(url: String, currentRetry: Int) async {
        if currentRetry < maxRetries {
            // Exponential backoff: 1s, 2s, 4s
            let delay = TimeInterval(1 << currentRetry)

            await MainActor.run {
                self.retryCount[url] = currentRetry + 1
            }

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if !Task.isCancelled {
                loadImage(url: url)
            }
        } else {
            await MainActor.run {
                self.images[url] = ReaderImage(url: url, state: .failed)
            }
        }
    }

    // TODO: smart grouping
    private func groupImages() {
        var newGroups: [ReaderGroup] = []
        let groupSize: Int

        switch imageLayout {
        case .auto:
            let isLandscape = UIScreen.main.bounds.width > UIScreen.main.bounds.height
            groupSize = isLandscape ? 2 : 1
        case .onePerRow:
            groupSize = 1
        case .twoPerRow:
            groupSize = 2
        }

        var i = 0
        while i < urls.count {
            let url = urls[i]

            let isWide = isImageWide(url: url)

            if isWide {
                // Wide images get their own group regardless of orientation
                newGroups.append(ReaderGroup(urls: [url]))
                i += 1
            } else {
                // Build a group of non-wide images up to groupSize
                var groupUrls: [String] = []
                var j = i

                while j < urls.count, groupUrls.count < groupSize {
                    let currentUrl = urls[j]

                    // If we encounter a wide image while building the group, stop here
                    if isImageWide(url: currentUrl) {
                        break
                    }

                    groupUrls.append(currentUrl)
                    j += 1
                }

                newGroups.append(ReaderGroup(urls: groupUrls))
                i = j
            }
        }

        groups = newGroups
    }

    private func isImageWide(url: String) -> Bool {
        guard let readerImage = images[url], case let .success(image) = readerImage.state else {
            return false
        }

        return image.size.width > image.size.height
    }
}
