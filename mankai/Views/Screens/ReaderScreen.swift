//
//  ReaderScreen.swift
//  mankai
//
//  Created by Travis XU on 30/6/2025.
//

import CoreData
import SwiftUI
import UIKit

enum ReaderScreenConstants {
    static let defaultReadingDirection: ReadingDirection = .rightToLeft
}

let LOADER_VIEW_ID = 1
let ERROR_VIEW_ID = 2
let LOADING_IMAGE_VIEW_ID = 3
let ERROR_IMAGE_VIEW_ID = 4
let PAGE_INFO_BUTTON_ID = 5
let PAGE_SLIDER_ID = 6
let PREVIOUS_CHAPTER_BUTTON_ID = 7
let PREVIOUS_BUTTON_ID = 8
let NEXT_BUTTON_ID = 9
let NEXT_CHAPTER_BUTTON_ID = 10
let TOP_OVERSCROLL_ARROW_TAG = 11
let TOP_OVERSCROLL_TEXT_TAG = 12
let BOTTOM_OVERSCROLL_ARROW_TAG = 13
let BOTTOM_OVERSCROLL_TEXT_TAG = 14

// MARK: - ReaderViewController

private class ReaderViewController: UIViewController, UIScrollViewDelegate {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter

    private var chapters: [Chapter]
    private var currentChapterIndex: Int
    private var initialPage: Int?
    private var jumpToPage: String?

    // Image management variables
    private var urls: [String] = []
    private var images: [String: UIImageView?] = [:]
    private var groups: [[String]] = []

    // Reading state variables
    private var currentPage: Int = 0
    private var imagesCenterY: [String: CGFloat] = [:]
    private var startY: CGFloat = 0.0

    // State variables for tab bar visibility
    var isTabBarHidden = false
    var isTabBarAnimating = false

    // State variables for navigation bar and bottom bar visibility
    var isNavigationBarHidden = false
    var isNavigationBarAnimating = false

    // UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let containerView = UIView()
    private let bottomBar = UIView()
    private let overscrollView = UIView()
    private let bottomOverscrollView = UIView()

    // Constraint references for dynamic updates
    private var containerLeadingConstraint: NSLayoutConstraint!
    private var containerTopConstraint: NSLayoutConstraint!
    private var containerWidthConstraint: NSLayoutConstraint!
    private var containerHeightConstraint: NSLayoutConstraint!
    private var contentHeightConstraint: NSLayoutConstraint!

    init(
        plugin: Plugin, manga: DetailedManga, chaptersKey: String, chapter: Chapter,
        initialPage: Int?
    ) {
        self.plugin = plugin
        self.manga = manga
        self.chaptersKey = chaptersKey
        self.chapter = chapter
        self.initialPage = initialPage

        self.chapters = manga.chapters[chaptersKey] ?? []
        self.currentChapterIndex = chapters.firstIndex(where: { $0.id == chapter.id }) ?? -1

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBarAppearance()
        setupUI()
        setupGestures()
        setupConstraints()

        loadChapter()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateGrouping),
            name: UIDevice.orientationDidChangeNotification,
            object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateGrouping),
            name: UserDefaults.didChangeNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        saveTimer?.invalidate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        forceSaveRecord()
        showTabBar()
        showNavigationBar()
        restoreNavigationBarAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        hideTabBar()
        setupNavigationBarAppearance()

        parent?.title = chapter.title ?? chapter.id ?? String(localized: "nil")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateImageViews()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return contentView
    }

    // MARK: - Observer

    @objc private func updateGrouping() {
        groupImages()
        syncPage()
    }

    // MARK: - Scroll Event Monitoring

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentPageFromScroll()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard decelerate else { return }

        let offsetY = scrollView.contentOffset.y
        let maxScrollY = max(0, scrollView.contentSize.height - scrollView.bounds.height) + 125

        if offsetY < -125 {
            if currentChapterIndex > 0 {
                currentChapterIndex -= 1
                loadChapter()
            }
        } else if offsetY > maxScrollY {
            if currentChapterIndex < chapters.count - 1 {
                currentChapterIndex += 1
                loadChapter()
            }
        }
    }

    private func updateCurrentPageFromScroll() {
        let zoomScale = scrollView.zoomScale
        let scrollY = scrollView.contentOffset.y + startY

        // Find which page is currently in the center of the viewport
        let viewportCenter = scrollY + (view.bounds.height / 2)

        var closestPage = 0
        var closestDistance = CGFloat.greatestFiniteMagnitude

        for (index, url) in urls.enumerated() {
            if let centerY = imagesCenterY[url] {
                let scaledCenterY = centerY * zoomScale
                let distance = abs(scaledCenterY - viewportCenter)
                if distance < closestDistance {
                    closestDistance = distance
                    closestPage = index
                }
            }
        }

        // Only update if page actually changed
        if closestPage != currentPage {
            currentPage = closestPage
            updateBottomBar()
            saveRecord()
        }
    }

    // MARK: - Record

    private var lastSavedPage: Int = -1
    private var saveTimer: Timer?

    private func saveRecord() {
        guard currentChapterIndex >= 0, currentChapterIndex < chapters.count else { return }

        if saveTimer != nil { return }

        saveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.performSave()
            self?.saveTimer = nil
        }
    }

    private func performSave() {
        guard currentChapterIndex >= 0, currentChapterIndex < chapters.count else { return }
        if currentPage == lastSavedPage { return }

        let context = DbService.shared.context
        let currentChapter = chapters[currentChapterIndex]

        do {
            // Find or create MangaData
            let mangaRequest = MangaData.fetchRequest()
            mangaRequest.predicate = NSPredicate(
                format: "id == %@ AND plugin == %@", manga.id, plugin.id)

            let existingMangaData = try context.fetch(mangaRequest).first
            let mangaData: MangaData

            if let existingMangaData = existingMangaData {
                mangaData = existingMangaData
            } else {
                mangaData = MangaData(context: context)
                mangaData.id = manga.id
                mangaData.plugin = plugin.id
            }

            // Update manga metadata - encode the complete DetailedManga object
            if let mangaMetaData = try? JSONEncoder().encode(manga) {
                mangaData.meta = String(data: mangaMetaData, encoding: .utf8)
            }

            // Find or create RecordData
            let recordData: RecordData
            if let existingRecord = mangaData.record {
                recordData = existingRecord
            } else {
                recordData = RecordData(context: context)
                mangaData.record = recordData
                recordData.target = mangaData
            }

            // Update record data
            recordData.chapterId = currentChapter.id
            recordData.chapterTitle = currentChapter.title
            recordData.page = NSDecimalNumber(value: currentPage)
            recordData.date = Date()

            // Save context
            try context.save()
            lastSavedPage = currentPage
        } catch {
            print("Failed to save record: \(error)")
        }
    }

    private func forceSaveRecord() {
        saveTimer?.invalidate()
        saveTimer = nil
        performSave()
    }

    // MARK: - Load Chapter

    private func loadChapter() {
        guard currentChapterIndex >= 0, currentChapterIndex < chapters.count else {
            addErrorView()
            return
        }

        // Reset UI
        scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: false)
        containerView.subviews.forEach { $0.removeFromSuperview() }
        addLoadingView()
        updateOverscrollViewsVisibility()
        bottomOverscrollView.isHidden = true
        overscrollView.isHidden = true

        // Reset state
        urls = []
        images = [:]
        groups = []
        currentPage = 0
        imagesCenterY = [:]
        startY = 0.0

        // Set title
        let chapter = chapters[currentChapterIndex]
        parent?.title = chapter.title ?? chapter.id ?? String(localized: "nil")

        Task {
            do {
                urls = try await plugin.getChapter(
                    manga: manga, chapter: chapter)

                if let initialPage = self.initialPage {
                    self.jumpToPage = urls[initialPage]
                }

                loadImages()
                updateBottomBar()
            } catch {
                addErrorView()
            }
        }
    }

    // MARK: - Load Images

    private func loadImages() {
        for url in urls {
            Task {
                do {
                    let imageData = try await plugin.getImage(url)
                    images[url] = UIImageView(image: UIImage(data: imageData))
                } catch {
                    images[url] = nil
                }

                groupImages()
            }
        }
    }

    // MARK: - Group Images

    private func groupImages() {
        groups = []

        let defaults = UserDefaults.standard
        let imageLayout =
            ImageLayout(rawValue: defaults.integer(forKey: SettingsKey.imageLayout.rawValue))
                ?? .auto

        let defaultGroupSize: Int
        switch imageLayout {
        case .auto:
            // Determine screen orientation
            let isLandscape = UIDevice.current.orientation.isLandscape

            // Default grouping size based on orientation
            defaultGroupSize = isLandscape ? 2 : 1
        case .onePerRow:
            defaultGroupSize = 1
        case .twoPerRow:
            defaultGroupSize = 2
        }

        var i = 0
        while i < urls.count {
            let url = urls[i]

            // Check if image is loaded and if it's a wide image
            let isWideImage = isImageWide(url: url)

            if isWideImage {
                // Wide images get their own group regardless of orientation
                groups.append([url])
                i += 1
            } else {
                // Build a group of non-wide images up to defaultGroupSize
                var group: [String] = []
                var j = i

                while j < urls.count && group.count < defaultGroupSize {
                    let currentUrl = urls[j]

                    // If we encounter a wide image while building the group, stop here
                    if isImageWide(url: currentUrl) {
                        break
                    }

                    group.append(currentUrl)
                    j += 1
                }

                groups.append(group)
                i = j
            }
        }

        updateImageViews()
    }

    private func isImageWide(url: String) -> Bool {
        guard let imageView = images[url], let image = imageView?.image else {
            return false
        }

        return image.size.width > image.size.height
    }

    // MARK: - Page Management

    private func navigateToPage(_ page: Int, animated: Bool = false) {
        guard page >= 0 && page < urls.count else { return }

        let targetUrl = urls[page]

        if let centerY = imagesCenterY[targetUrl] {
            let zoomScale = scrollView.zoomScale
            let scaledCenterY = centerY * zoomScale
            let targetScrollY = scaledCenterY + startY - (view.bounds.height / 2)

            // Limit scroll position to valid bounds
            let maxScrollY = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            let clampedScrollY = max(0, min(targetScrollY, maxScrollY))

            scrollView.setContentOffset(
                CGPoint(x: 0, y: clampedScrollY),
                animated: animated)

            currentPage = page
            updateBottomBar()
            saveRecord()
        }
    }

    private func syncPage() {
        navigateToPage(currentPage)
    }

    // MARK: - Navigation Bar Appearance

    private func setupNavigationBarAppearance() {
        guard let navigationController = navigationController else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)

        navigationController.navigationBar.scrollEdgeAppearance = appearance
    }

    private func restoreNavigationBarAppearance() {
        guard let navigationController = navigationController else { return }

        navigationController.navigationBar.scrollEdgeAppearance = nil
    }

    // MARK: - Tab Bar

    func hideTabBar() {
        if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(true, animated: true)
        } else {
            guard let tabBar = tabBarController?.tabBar else { return }
            if isTabBarAnimating || isTabBarHidden { return }
            isTabBarAnimating = true

            DispatchQueue.main.async {
                if let tabBarControllerView = self.tabBarController?.view {
                    tabBarControllerView.frame = CGRect(
                        x: tabBarControllerView.frame.origin.x,
                        y: tabBarControllerView.frame.origin.y,
                        width: tabBarControllerView.frame.width,
                        height: UIScreen.main.bounds.height + tabBar.frame.height)
                }
            }

            UIView.animate(
                withDuration: 0.2, delay: 0, options: [.curveEaseIn],
                animations: {
                    tabBar.frame.origin.y = UIScreen.main.bounds.height
                    tabBar.alpha = 0.0
                    self.view.layoutIfNeeded()
                }) { _ in
                    tabBar.isHidden = true
                    self.isTabBarAnimating = false
                }
            isTabBarHidden = true
        }
    }

    func showTabBar() {
        if #available(iOS 18.0, *) {
            tabBarController?.setTabBarHidden(false, animated: true)
        } else {
            guard let tabBar = tabBarController?.tabBar else { return }
            tabBar.isHidden = false
            if isTabBarAnimating || !isTabBarHidden { return }

            isTabBarAnimating = true

            // Spring animation for a playful bounce
            UIView.animate(
                withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6,
                initialSpringVelocity: 1.0, options: [.curveEaseOut],
                animations: {
                    tabBar.frame.origin.y = UIScreen.main.bounds.height - tabBar.frame.height
                    tabBar.alpha = 1.0
                    self.view.layoutIfNeeded()
                }) { _ in
                    self.isTabBarAnimating = false
                }
            isTabBarHidden = false
        }
    }

    // MARK: - Navigation Bar

    func hideNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        if isNavigationBarAnimating || isNavigationBarHidden { return }
        isNavigationBarAnimating = true

        UIView.animate(
            withDuration: 0.2, delay: 0, options: [.curveLinear],
            animations: {
                navigationBar.transform = .init(
                    translationX: 0, y: -(navigationBar.frame.height + navigationBar.frame.origin.y))

                self.bottomBar.transform = .init(
                    translationX: 0, y: self.bottomBar.frame.height)

                self.view.layoutIfNeeded()
            }) { _ in

                self.isNavigationBarAnimating = false
            }

        isNavigationBarHidden = true
    }

    func showNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        if isNavigationBarAnimating || !isNavigationBarHidden { return }

        isNavigationBarAnimating = true

        UIView.animate(
            withDuration: 0.2, delay: 0, options: [.curveLinear],
            animations: {
                navigationBar.transform = .init(translationX: 0, y: 0)

                // Show bottom bar as well
                self.bottomBar.transform = .init(translationX: 0, y: 0)

                self.view.layoutIfNeeded()
            }) { _ in
                self.isNavigationBarAnimating = false
            }

        isNavigationBarHidden = false
    }

    // MARK: - Gestures

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap(_:)))
        scrollView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleScreenTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: scrollView)
        let width = scrollView.bounds.width

        if location.x < width / 3 {
            // Left third: previous page
            navigateToPage(currentPage - 1, animated: true)
        } else if location.x > width * 2 / 3 {
            // Right third: next page
            navigateToPage(currentPage + 1, animated: true)
        } else {
            // Middle third: toggle navigation bar
            if isNavigationBarHidden {
                showNavigationBar()
            } else {
                hideNavigationBar()
            }
        }
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.maximumZoomScale = 3
        scrollView.delegate = self

        // Configure overscroll view
        overscrollView.translatesAutoresizingMaskIntoConstraints = false
        setupOverscrollView()

        // Configure bottom overscroll view
        bottomOverscrollView.translatesAutoresizingMaskIntoConstraints = false
        setupBottomOverscrollView()

        // Configure content view
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Configure container view
        containerView.translatesAutoresizingMaskIntoConstraints = false

        // Add views to hierarchy
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        scrollView.addSubview(overscrollView)
        scrollView.addSubview(bottomOverscrollView)
        contentView.addSubview(containerView)

        // Configure bottom bar
        setupBottomBar()
    }

    private func setupConstraints() {
        // Create container constraints with references
        containerLeadingConstraint = containerView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor)
        containerTopConstraint = containerView.topAnchor.constraint(equalTo: contentView.topAnchor)
        containerWidthConstraint = containerView.widthAnchor.constraint(equalToConstant: 0)
        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: 0)

        // Create content height constraint with reference
        contentHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // Scroll view constraints
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Content view constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            contentHeightConstraint,

            // Container view constraints
            containerLeadingConstraint,
            containerTopConstraint,
            containerWidthConstraint,
            containerHeightConstraint,

            // Overscroll view constraints
            overscrollView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            overscrollView.bottomAnchor.constraint(equalTo: scrollView.topAnchor, constant: -20),

            // Bottom overscroll view constraints
            bottomOverscrollView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            bottomOverscrollView.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 20),

            // Bottom bar constraints
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Loading View

    private func addLoadingView() {
        view.viewWithTag(ERROR_VIEW_ID)?.removeFromSuperview()
        guard view.viewWithTag(LOADER_VIEW_ID) == nil else { return }

        // Create activity indicator
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        activityIndicator.tag = LOADER_VIEW_ID

        view.addSubview(activityIndicator)

        // Set up constraints
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Error View

    private func addErrorView() {
        view.viewWithTag(LOADER_VIEW_ID)?.removeFromSuperview()
        guard view.viewWithTag(ERROR_VIEW_ID) == nil else { return }

        // Create error container
        let errorContainer = UIView()
        errorContainer.translatesAutoresizingMaskIntoConstraints = false
        errorContainer.tag = ERROR_VIEW_ID

        // Create error icon
        let errorIcon = UIImageView()
        errorIcon.image = UIImage(systemName: "exclamationmark.circle")
        errorIcon.tintColor = .secondaryLabel
        errorIcon.translatesAutoresizingMaskIntoConstraints = false

        // Create error label
        let errorLabel = UILabel()
        errorLabel.text = String(localized: "failedToLoadChapter")
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false

        // Create retry label
        let retryLabel = UILabel()
        retryLabel.text = String(localized: "tapToRetry")
        retryLabel.textColor = .secondaryLabel
        retryLabel.textAlignment = .center
        retryLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        errorContainer.addSubview(errorIcon)
        errorContainer.addSubview(errorLabel)
        errorContainer.addSubview(retryLabel)
        view.addSubview(errorContainer)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(retryLoadChapter))
        errorContainer.addGestureRecognizer(tapGesture)
        errorContainer.isUserInteractionEnabled = true

        // Set up constraints
        NSLayoutConstraint.activate([
            errorContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            errorContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            errorIcon.topAnchor.constraint(equalTo: errorContainer.topAnchor),
            errorIcon.centerXAnchor.constraint(equalTo: errorContainer.centerXAnchor),
            errorIcon.widthAnchor.constraint(equalToConstant: 48),
            errorIcon.heightAnchor.constraint(equalToConstant: 48),

            errorLabel.topAnchor.constraint(equalTo: errorIcon.bottomAnchor, constant: 20),
            errorLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),

            retryLabel.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 8),
            retryLabel.leadingAnchor.constraint(equalTo: errorContainer.leadingAnchor),
            retryLabel.trailingAnchor.constraint(equalTo: errorContainer.trailingAnchor),
            retryLabel.bottomAnchor.constraint(equalTo: errorContainer.bottomAnchor),
        ])
    }

    @objc private func retryLoadChapter() {
        loadChapter()
    }

    // MARK: - Helper Methods for Image View Creation

    private func createErrorImageView() -> UIView {
        let containerView = UIView()

        // Create error icon
        let errorIcon = UIImageView()
        errorIcon.image = UIImage(systemName: "photo.badge.exclamationmark")
        errorIcon.tintColor = .secondaryLabel
        errorIcon.translatesAutoresizingMaskIntoConstraints = false
        errorIcon.tag = ERROR_IMAGE_VIEW_ID

        containerView.addSubview(errorIcon)

        // Center the error icon
        NSLayoutConstraint.activate([
            errorIcon.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            errorIcon.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            errorIcon.widthAnchor.constraint(equalToConstant: 48),
            errorIcon.heightAnchor.constraint(equalToConstant: 48),
        ])

        return containerView
    }

    private func createLoadingImageView() -> UIView {
        let containerView = UIView()

        // Create loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        loadingIndicator.tag = LOADING_IMAGE_VIEW_ID

        containerView.addSubview(loadingIndicator)

        // Center the loading indicator
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])

        return containerView
    }

    // MARK: - Image View Management Helper Methods

    private enum ImageViewState {
        case loading
        case loaded(UIImageView)
        case failed
    }

    private func getImageViewState(for url: String) -> ImageViewState {
        if let imageViewOptional = images[url] {
            if let imageView = imageViewOptional {
                return .loaded(imageView)
            } else {
                return .failed
            }
        } else {
            return .loading
        }
    }

    private func updateViewFrame(_ view: UIView, url: String, frames: [String: CGRect]) {
        if let frame = frames[url] {
            view.frame = frame
        }
    }

    private func replaceView(
        _ oldView: UIView, with newView: UIView, tag: Int, url: String, frames: [String: CGRect]
    ) {
        oldView.removeFromSuperview()
        addImageViewToContent(newView, tag: tag, url: url, frames: frames)
    }

    private func addImageViewToContent(
        _ view: UIView, tag: Int, url: String, frames: [String: CGRect]
    ) {
        view.tag = tag
        updateViewFrame(view, url: url, frames: frames)
        containerView.addSubview(view)
    }

    private func handleExistingImageView(
        _ existingView: UIView, url: String, tag: Int, frames: [String: CGRect]
    ) {
        let currentState = getImageViewState(for: url)

        switch currentState {
        case .loaded(let imageView):
            if existingView != imageView {
                replaceView(existingView, with: imageView, tag: tag, url: url, frames: frames)
                imageView.contentMode = .scaleToFill
            } else {
                updateViewFrame(existingView, url: url, frames: frames)
            }

        case .failed:
            let isErrorView = existingView.viewWithTag(ERROR_IMAGE_VIEW_ID) != nil

            if !isErrorView {
                let errorImageView = createErrorImageView()
                replaceView(existingView, with: errorImageView, tag: tag, url: url, frames: frames)
            } else {
                updateViewFrame(existingView, url: url, frames: frames)
            }

        case .loading:
            let isLoadingView = existingView.viewWithTag(LOADING_IMAGE_VIEW_ID) != nil

            if !isLoadingView {
                let loadingImageView = createLoadingImageView()
                replaceView(
                    existingView, with: loadingImageView, tag: tag, url: url, frames: frames)
            } else {
                updateViewFrame(existingView, url: url, frames: frames)
            }
        }
    }

    private func createNewImageView(url: String, tag: Int, frames: [String: CGRect]) {
        let currentState = getImageViewState(for: url)

        switch currentState {
        case .loaded(let imageView):
            addImageViewToContent(imageView, tag: tag, url: url, frames: frames)
            imageView.contentMode = .scaleToFill

        case .failed:
            let errorImageView = createErrorImageView()
            addImageViewToContent(errorImageView, tag: tag, url: url, frames: frames)

        case .loading:
            let loadingImageView = createLoadingImageView()
            addImageViewToContent(loadingImageView, tag: tag, url: url, frames: frames)
        }
    }

    private func removeLoadingAndErrorViews() {
        view.viewWithTag(LOADER_VIEW_ID)?.removeFromSuperview()
        view.viewWithTag(ERROR_VIEW_ID)?.removeFromSuperview()
    }

    private func calculateImageRatios() -> [String: CGFloat] {
        return images.compactMapValues { imageView in
            guard let image = imageView?.image else { return nil }
            return image.size.width / image.size.height
        }
    }

    private func calculateModeRatio(from ratios: [String: CGFloat]) -> CGFloat {
        let ratioValues = Array(ratios.values)
        guard !ratioValues.isEmpty else { return 1 }

        var counts: [CGFloat: Int] = [:]

        for value in ratioValues {
            let rounded = (value * 100).rounded() / 100
            counts[rounded, default: 0] += 1
        }

        let maxCount = counts.values.max() ?? 0
        let modeCandidates = counts.filter { $0.value == maxCount }.map { $0.key }

        return modeCandidates.min() ?? 1
    }

    private func calculateFrames(
        ratios: [String: CGFloat], mode: CGFloat
    ) -> ([String: CGRect], CGFloat) {
        let defaults = UserDefaults.standard
        let readingDirection =
            ReadingDirection(
                rawValue: defaults.integer(forKey: SettingsKey.readingDirection.rawValue))
            ?? ReaderScreenConstants.defaultReadingDirection

        var frames: [String: CGRect] = [:]
        imagesCenterY = [:]
        var currentY = 0.0

        let window = view.window!
        let safeFrame = window.safeAreaLayoutGuide.layoutFrame
        let width = safeFrame.width

        for group in groups {
            let ratiosSum: CGFloat = group.reduce(0) { result, url in
                result + ratios[url, default: mode]
            }

            let height = width / ratiosSum
            var currentX = 0.0

            for url in readingDirection == .rightToLeft ? group.reversed() : group {
                let imageWidth = height * ratios[url, default: mode]

                let frame = CGRect(
                    x: currentX,
                    y: currentY,
                    width: imageWidth,
                    height: height)

                frames[url] = frame
                imagesCenterY[url] = height / 2 + currentY
                currentX += imageWidth
            }

            currentY += height
        }

        return (frames, currentY)
    }

    // MARK: - Image Views

    private func updateImageViewsWithFrames(_ frames: [String: CGRect]) {
        for url in urls {
            var hasher = Hasher()
            hasher.combine(url)
            let tag = hasher.finalize()

            let existingView = containerView.viewWithTag(tag)

            if let existingView = existingView {
                handleExistingImageView(existingView, url: url, tag: tag, frames: frames)
            } else {
                createNewImageView(url: url, tag: tag, frames: frames)
            }
        }
    }

    private func updateContentSize(finalY: CGFloat) {
        guard let navigationBar = navigationController?.navigationBar else { return }
        startY = view.safeAreaInsets.top - navigationBar.frame.height

        containerLeadingConstraint.constant = view.safeAreaInsets.left
        containerTopConstraint.constant = startY
        containerWidthConstraint.constant = view.safeAreaLayoutGuide.layoutFrame.width
        containerHeightConstraint.constant = finalY

        contentHeightConstraint.constant =
            finalY + startY + view.safeAreaInsets.bottom

        if overscrollView.isHidden {
            overscrollView.isHidden = false
            bottomOverscrollView.isHidden = false
        }

        view.layoutIfNeeded()

        if let initialPage = initialPage,
           let jumpToPage = jumpToPage,
           images[jumpToPage] != nil
        {
            navigateToPage(initialPage)
            self.initialPage = nil
            self.jumpToPage = nil
        }
    }

    private func updateImageViews() {
        guard !images.isEmpty else { return }

        removeLoadingAndErrorViews()

        let ratios = calculateImageRatios()
        let mode = calculateModeRatio(from: ratios)
        let (frames, finalY) = calculateFrames(
            ratios: ratios, mode: mode)

        updateImageViewsWithFrames(frames)
        updateContentSize(finalY: finalY)
    }

    // MARK: - Bottom Bar

    private func setupBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        // Create blur effect view
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = bottomBar.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Add blur effect as background
        bottomBar.addSubview(blurEffectView)

        // Add a subtle border at the top
        let borderLayer = CALayer()
        borderLayer.backgroundColor = UIColor.separator.cgColor
        borderLayer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 0.5)
        bottomBar.layer.addSublayer(borderLayer)

        // Create horizontal stack view for bottom bar controls
        let bottomStackView = UIStackView()
        bottomStackView.translatesAutoresizingMaskIntoConstraints = false
        bottomStackView.axis = .horizontal
        bottomStackView.distribution = .fillProportionally
        bottomStackView.alignment = .center

        // Add control buttons
        let pageInfoButton = createBottomBarButton(title: "1 / 1")
        pageInfoButton.tag = PAGE_INFO_BUTTON_ID

        let previousChapterButton = createBottomBarButton(systemImage: "chevron.left.to.line")
        previousChapterButton.tag = PREVIOUS_CHAPTER_BUTTON_ID
        previousChapterButton.isEnabled = false

        let previousButton = createBottomBarButton(systemImage: "chevron.left")
        previousButton.tag = PREVIOUS_BUTTON_ID
        previousChapterButton.isEnabled = false

        let nextButton = createBottomBarButton(systemImage: "chevron.right")
        nextButton.tag = NEXT_BUTTON_ID
        previousChapterButton.isEnabled = currentChapterIndex > 0

        let nextChapterButton = createBottomBarButton(systemImage: "chevron.right.to.line")
        nextChapterButton.tag = NEXT_CHAPTER_BUTTON_ID
        nextChapterButton.isEnabled = currentChapterIndex < chapters.count - 1

        // Add button actions
        previousChapterButton.addTarget(
            self, action: #selector(previousChapterButtonTapped), for: .touchUpInside)
        previousButton.addTarget(self, action: #selector(previousButtonTapped), for: .touchUpInside)
        pageInfoButton.addTarget(self, action: #selector(pageInfoButtonTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        nextChapterButton.addTarget(
            self, action: #selector(nextChapterButtonTapped), for: .touchUpInside)

        bottomStackView.addArrangedSubview(previousChapterButton)
        bottomStackView.addArrangedSubview(previousButton)
        bottomStackView.addArrangedSubview(pageInfoButton)
        bottomStackView.addArrangedSubview(nextButton)
        bottomStackView.addArrangedSubview(nextChapterButton)

        bottomBar.addSubview(bottomStackView)

        // Create slider for page navigation
        let pageSlider = UISlider()
        pageSlider.tag = PAGE_SLIDER_ID
        pageSlider.translatesAutoresizingMaskIntoConstraints = false
        pageSlider.minimumValue = 1
        pageSlider.maximumValue = 1
        pageSlider.value = 1
        pageSlider.addTarget(self, action: #selector(pageSliderValueChanged), for: .valueChanged)

        bottomBar.addSubview(pageSlider)

        // Layout constraints for bottom stack view and slider
        NSLayoutConstraint.activate([
            bottomStackView.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 20),
            bottomStackView.leadingAnchor.constraint(
                equalTo: bottomBar.leadingAnchor, constant: 20),
            bottomStackView.trailingAnchor.constraint(
                equalTo: bottomBar.trailingAnchor, constant: -20),

            pageSlider.topAnchor.constraint(equalTo: bottomStackView.bottomAnchor, constant: 10),
            pageSlider.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            pageSlider.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            pageSlider.bottomAnchor.constraint(
                equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])

        view.addSubview(bottomBar)
    }

    private func createBottomBarButton(title: String? = nil, systemImage: String? = nil) -> UIButton {
        var configuration = UIButton.Configuration.borderless()
        configuration.title = title

        if let systemImage = systemImage {
            configuration.image = UIImage(systemName: systemImage)
        }

        let button = UIButton(configuration: configuration)

        return button
    }

    private func updateBottomBar() {
        guard let pageInfoButton = bottomBar.viewWithTag(PAGE_INFO_BUTTON_ID) as? UIButton,
              let previousChapterButton = bottomBar.viewWithTag(PREVIOUS_CHAPTER_BUTTON_ID) as? UIButton,
              let previousButton = bottomBar.viewWithTag(PREVIOUS_BUTTON_ID) as? UIButton,
              let nextButton = bottomBar.viewWithTag(NEXT_BUTTON_ID) as? UIButton,
              let nextChapterButton = bottomBar.viewWithTag(NEXT_CHAPTER_BUTTON_ID) as? UIButton,
              let pageSlider = bottomBar.viewWithTag(PAGE_SLIDER_ID) as? UISlider
        else {
            return
        }

        let totalPages = urls.count
        pageInfoButton.setTitle("\(currentPage + 1) / \(totalPages)", for: .normal)
        previousButton.isEnabled = currentPage != 0
        nextButton.isEnabled = currentPage < urls.count - 1
        previousChapterButton.isEnabled = currentChapterIndex > 0
        nextChapterButton.isEnabled = currentChapterIndex < chapters.count - 1

        pageSlider.maximumValue = Float(totalPages)
        pageSlider.value = Float(currentPage + 1)
    }

    // MARK: - Bottom Bar Actions

    @objc private func previousChapterButtonTapped() {
        currentChapterIndex -= 1
        loadChapter()
    }

    @objc private func previousButtonTapped() {
        navigateToPage(currentPage - 1)
    }

    @objc private func pageInfoButtonTapped() {
        print("Page info button tapped")
        // TODO: Implement page info action
    }

    @objc private func nextButtonTapped() {
        navigateToPage(currentPage + 1)
    }

    @objc private func nextChapterButtonTapped() {
        currentChapterIndex += 1
        loadChapter()
    }

    @objc private func pageSliderValueChanged(_ sender: UISlider) {
        let targetPage = Int(sender.value) - 1
        guard targetPage >= 0 && targetPage < urls.count else { return }

        navigateToPage(targetPage)
    }

    // MARK: - Overscroll Views

    private func setupOverscrollView() {
        // Create arrow image view
        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.up"))
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.tintColor = .secondaryLabel
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tag = TOP_OVERSCROLL_ARROW_TAG

        // Create text label
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = String(localized: "releaseToLoadPreviousChapter")
        textLabel.textColor = .secondaryLabel
        textLabel.textAlignment = .center
        textLabel.tag = TOP_OVERSCROLL_TEXT_TAG

        // Add subviews
        overscrollView.addSubview(arrowImageView)
        overscrollView.addSubview(textLabel)

        // Set up constraints
        NSLayoutConstraint.activate([
            arrowImageView.topAnchor.constraint(equalTo: overscrollView.topAnchor, constant: 8),
            arrowImageView.centerXAnchor.constraint(equalTo: overscrollView.centerXAnchor),
            arrowImageView.heightAnchor.constraint(equalToConstant: 48),
            arrowImageView.widthAnchor.constraint(equalToConstant: 48),

            textLabel.topAnchor.constraint(equalTo: arrowImageView.bottomAnchor, constant: 8),
            textLabel.leadingAnchor.constraint(equalTo: overscrollView.leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: overscrollView.trailingAnchor, constant: -8),
            textLabel.bottomAnchor.constraint(equalTo: overscrollView.bottomAnchor, constant: -8),
        ])
    }

    private func setupBottomOverscrollView() {
        // Create arrow image view (pointing down for bottom)
        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        arrowImageView.tintColor = .secondaryLabel
        arrowImageView.contentMode = .scaleAspectFit
        arrowImageView.tag = BOTTOM_OVERSCROLL_ARROW_TAG

        // Create text label
        let textLabel = UILabel()
        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.text = String(localized: "releaseToLoadNextChapter")
        textLabel.textColor = .secondaryLabel
        textLabel.textAlignment = .center
        textLabel.tag = BOTTOM_OVERSCROLL_TEXT_TAG

        // Add subviews
        bottomOverscrollView.addSubview(arrowImageView)
        bottomOverscrollView.addSubview(textLabel)

        // Set up constraints
        NSLayoutConstraint.activate([
            textLabel.topAnchor.constraint(equalTo: bottomOverscrollView.topAnchor, constant: 20),
            textLabel.leadingAnchor.constraint(equalTo: bottomOverscrollView.leadingAnchor, constant: 8),
            textLabel.trailingAnchor.constraint(equalTo: bottomOverscrollView.trailingAnchor, constant: -8),
            textLabel.bottomAnchor.constraint(equalTo: bottomOverscrollView.bottomAnchor, constant: -8),

            arrowImageView.topAnchor.constraint(equalTo: textLabel.bottomAnchor, constant: 8),
            arrowImageView.centerXAnchor.constraint(equalTo: bottomOverscrollView.centerXAnchor),
            arrowImageView.heightAnchor.constraint(equalToConstant: 48),
            arrowImageView.widthAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func updateOverscrollViewsVisibility() {
        // Update top overscroll view
        if let arrowImageView = overscrollView.viewWithTag(TOP_OVERSCROLL_ARROW_TAG) as? UIImageView,
           let textLabel = overscrollView.viewWithTag(TOP_OVERSCROLL_TEXT_TAG) as? UILabel
        {
            if currentChapterIndex > 0 {
                arrowImageView.image = UIImage(systemName: "chevron.up")
                textLabel.text = String(localized: "releaseToLoadPreviousChapter")
            } else {
                arrowImageView.image = UIImage(systemName: "xmark")
                textLabel.text = String(localized: "noPreviousChapter")
            }
        }

        // Update bottom overscroll view
        if let arrowImageView = bottomOverscrollView.viewWithTag(BOTTOM_OVERSCROLL_ARROW_TAG) as? UIImageView,
           let textLabel = bottomOverscrollView.viewWithTag(BOTTOM_OVERSCROLL_TEXT_TAG) as? UILabel
        {
            if currentChapterIndex < chapters.count - 1 {
                arrowImageView.image = UIImage(systemName: "chevron.down")
                textLabel.text = String(localized: "releaseToLoadNextChapter")
            } else {
                arrowImageView.image = UIImage(systemName: "xmark")
                textLabel.text = String(localized: "noNextChapter")
            }
        }
    }
}

// MARK: - ReaderViewControllerWrapper

private struct ReaderViewControllerWrapper: UIViewControllerRepresentable {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter
    let initialPage: Int?

    func makeUIViewController(context: Context) -> ReaderViewController {
        return ReaderViewController(
            plugin: plugin,
            manga: manga,
            chaptersKey: chaptersKey,
            chapter: chapter,
            initialPage: initialPage)
    }

    func updateUIViewController(_ uiViewController: ReaderViewController, context: Context) {
        // Handle any updates if needed
    }
}

// MARK: - SwiftUI Wrapper

struct ReaderScreen: View {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter
    var initialPage: Int? = nil

    var body: some View {
        NavigationStack {
            ReaderViewControllerWrapper(
                plugin: plugin,
                manga: manga,
                chaptersKey: chaptersKey,
                chapter: chapter,
                initialPage: initialPage)
                .ignoresSafeArea()
        }
    }
}
