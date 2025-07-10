//
//  ReaderScreen.swift
//  mankai
//
//  Created by Travis XU on 30/6/2025.
//

import SwiftUI
import UIKit

let LOADER_VIEW_ID = 1
let ERROR_VIEW_ID = 2
let LOADING_IMAGE_VIEW_ID = 3
let ERROR_IMAGE_VIEW_ID = 4

// MARK: - ReaderViewController

class ReaderViewController: UIViewController {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter

    let chapters: [Chapter]
    var currentIndex: Int

    init(plugin: Plugin, manga: DetailedManga, chaptersKey: String, chapter: Chapter) {
        self.plugin = plugin
        self.manga = manga
        self.chaptersKey = chaptersKey
        self.chapter = chapter

        self.chapters = manga.chapters[chaptersKey] ?? []
        self.currentIndex = chapters.firstIndex(where: { $0.id == chapter.id }) ?? -1

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
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

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

    // MARK: - Load Chapter

    private var urls: [String] = []

    private func loadChapter() {
        guard currentIndex != -1 else {
            addErrorView()
            return
        }

        Task {
            do {
                urls = try await plugin.getChapter(manga: manga, chapter: chapters[currentIndex])
                loadImages()
            } catch {
                addErrorView()
            }
        }
    }

    // MARK: - Load Images

    private var images: [String: UIImageView?] = [:]

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

    private var groups: [[String]] = []

    private func groupImages() {
        groups = []

        for i in stride(from: 0, to: urls.count, by: 2) {
            let endIndex = min(i + 2, urls.count)
            let group = Array(urls[i ..< endIndex])
            groups.append(group)
        }

        updateImageViews()
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
        tabBarController?.setTabBarHidden(true, animated: true)
    }

    func showTabBar() {
        tabBarController?.setTabBarHidden(false, animated: true)
    }

    // MARK: - Navigation Bar

    var isNavigationBarHidden = false
    var isNavigationBarAnimating = false
    var isBottomBarHidden = false

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
        isBottomBarHidden = true
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
        isBottomBarHidden = false
    }

    // MARK: - Gestures

    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(scrollViewTapped))
        scrollView.addGestureRecognizer(tapGesture)
    }

    @objc private func scrollViewTapped() {
        // Toggle navigation bar and bottom bar visibility
        if isNavigationBarHidden {
            showNavigationBar()
        } else {
            hideNavigationBar()
        }
    }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Configure scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never

        // Configure content view
        contentView.translatesAutoresizingMaskIntoConstraints = false

        // Add views to hierarchy
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Configure bottom bar
        setupBottomBar()

        // Add loading view
        addLoadingView()
    }

    private func setupConstraints() {
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

            // Bottom bar constraints
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Loading View

    private func addLoadingView() {
        view.viewWithTag(ERROR_VIEW_ID)?.removeFromSuperview()

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
        addLoadingView()
        loadChapter()
    }

    // MARK: - Helper Methods for Image View Creation

    private func createErrorImageView() -> UIView {
        let containerView = UIView()

        // Create error icon
        let errorIcon = UIImageView()
        errorIcon.image = UIImage(systemName: "exclamationmark.circle")
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
        contentView.addSubview(view)
    }

    private func handleExistingImageView(
        _ existingView: UIView, url: String, tag: Int, frames: [String: CGRect]
    ) {
        let currentState = getImageViewState(for: url)

        switch currentState {
        case .loaded(let imageView):
            if existingView != imageView {
                replaceView(existingView, with: imageView, tag: tag, url: url, frames: frames)
                imageView.contentMode = .scaleAspectFit
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

        case .failed:
            let errorImageView = createErrorImageView()
            addImageViewToContent(errorImageView, tag: tag, url: url, frames: frames)

        case .loading:
            let loadingImageView = createLoadingImageView()
            addImageViewToContent(loadingImageView, tag: tag, url: url, frames: frames)
        }
    }

    // MARK: - Image Views

    private func updateImageViews() {
        removeLoadingAndErrorViews()

        let safeAreaInfo = calculateSafeAreaInfo()
        let ratios = calculateImageRatios()
        let mode = calculateModeRatio(from: ratios)
        let (frames, finalY) = calculateFrames(
            safeAreaInfo: safeAreaInfo, ratios: ratios, mode: mode)

        updateImageViewsWithFrames(frames)
        updateContentSize(finalY: finalY, safeAreaInfo: safeAreaInfo)
    }

    private func updateImageViewsWithFrames(_ frames: [String: CGRect]) {
        for url in urls {
            var hasher = Hasher()
            hasher.combine(url)
            let tag = hasher.finalize()

            let existingView = contentView.viewWithTag(tag)

            if let existingView = existingView {
                handleExistingImageView(existingView, url: url, tag: tag, frames: frames)
            } else {
                createNewImageView(url: url, tag: tag, frames: frames)
            }
        }
    }

    private func updateContentSize(finalY: CGFloat, safeAreaInfo: SafeAreaInfo) {
        contentView.frame.size.height = finalY + safeAreaInfo.bottomHeight
        scrollView.contentSize = contentView.frame.size
    }

    // MARK: - Frame Calculation Helper Methods

    private struct SafeAreaInfo {
        let width: CGFloat
        let topHeight: CGFloat
        let bottomHeight: CGFloat
        let leftWidth: CGFloat
    }

    private func removeLoadingAndErrorViews() {
        view.viewWithTag(LOADER_VIEW_ID)?.removeFromSuperview()
        view.viewWithTag(ERROR_VIEW_ID)?.removeFromSuperview()
    }

    private func calculateSafeAreaInfo() -> SafeAreaInfo {
        let window = view.window!
        let safeFrame = window.safeAreaLayoutGuide.layoutFrame

        return SafeAreaInfo(
            width: safeFrame.width,
            topHeight: window.safeAreaInsets.top,
            bottomHeight: window.safeAreaInsets.bottom,
            leftWidth: window.safeAreaInsets.left)
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
        safeAreaInfo: SafeAreaInfo, ratios: [String: CGFloat], mode: CGFloat
    ) -> ([String: CGRect], CGFloat) {
        var frames: [String: CGRect] = [:]
        var currentY = safeAreaInfo.topHeight
        let width = safeAreaInfo.width

        for group in groups {
            let ratiosSum: CGFloat = group.reduce(0) { result, url in
                result + ratios[url, default: mode]
            }

            let height = width / ratiosSum
            var currentX = safeAreaInfo.leftWidth

            for url in group {
                let imageWidth = height * ratios[url, default: mode]

                let frame = CGRect(
                    x: currentX,
                    y: currentY,
                    width: imageWidth,
                    height: height)

                frames[url] = frame
                currentX += imageWidth
            }

            currentY += height
        }

        return (frames, currentY)
    }

    // MARK: - Bottom Bar

    private let bottomBar = UIView()

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
        bottomStackView.distribution = .fillEqually
        bottomStackView.alignment = .center

        // Add control buttons
        let previousChapterButton = createBottomBarButton(systemImage: "chevron.left.to.line")
        let previousButton = createBottomBarButton(systemImage: "chevron.left")
        let pageInfoButton = createBottomBarButton(title: "1 / 20")
        let nextButton = createBottomBarButton(systemImage: "chevron.right")
        let nextChapterButton = createBottomBarButton(systemImage: "chevron.right.to.line")

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
        pageSlider.translatesAutoresizingMaskIntoConstraints = false
        pageSlider.minimumValue = 1
        pageSlider.maximumValue = 20 // TODO: Update with actual page count
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

    // MARK: - Bottom Bar Actions

    @objc private func previousChapterButtonTapped() {
        print("Previous chapter button tapped")
        // TODO: Implement previous chapter navigation
    }

    @objc private func previousButtonTapped() {
        print("Previous button tapped")
        // TODO: Implement previous page/chapter navigation
    }

    @objc private func pageInfoButtonTapped() {
        print("Page info button tapped")
        // TODO: Implement page info display or page selection
    }

    @objc private func nextButtonTapped() {
        print("Next button tapped")
        // TODO: Implement next page/chapter navigation
    }

    @objc private func nextChapterButtonTapped() {
        print("Next chapter button tapped")
        // TODO: Implement next chapter navigation
    }

    @objc private func pageSliderValueChanged(_ sender: UISlider) {
        let currentPage = Int(sender.value)
        print("Page slider changed to: \(currentPage)")
        // TODO: Implement page navigation based on slider value
    }
}

// MARK: - ReaderViewControllerWrapper

private struct ReaderViewControllerWrapper: UIViewControllerRepresentable {
    let plugin: Plugin
    let manga: DetailedManga
    let chaptersKey: String
    let chapter: Chapter

    func makeUIViewController(context: Context) -> ReaderViewController {
        return ReaderViewController(
            plugin: plugin,
            manga: manga,
            chaptersKey: chaptersKey,
            chapter: chapter)
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

    var body: some View {
        NavigationStack {
            ReaderViewControllerWrapper(
                plugin: plugin,
                manga: manga,
                chaptersKey: chaptersKey,
                chapter: chapter)
                .ignoresSafeArea()
        }
    }
}
