import Foundation
import ImageIO
import UniformTypeIdentifiers
import WidgetKit
import XCGLogger

/// Publishes the app's articles to the widget through `SharedArticleStore`.
///
/// The widget shows the article the user opened last, then the saved ones,
/// then the latest loaded ones, up to `maxArticles`. Updates arriving close
/// together (the managers all report during launch) are coalesced into one
/// publish, which writes the list once, asks WidgetKit to reload once, and only
/// then fetches the images that are still missing – each one a single time,
/// downsampled so the extension stays within its memory limit – followed by
/// one more reload when any arrived.
final class WidgetSyncManager: WidgetSyncManagerProtocol {
    typealias ImageDownloader = (URL, @escaping (Data?) -> Void) -> Void

    static let maxArticles = 10
    static let widgetKind = "ArticlesWidget"
    static let untitled = "Untitled article"

    private let store: SharedArticleStore
    private let defaults: UserDefaults
    private let imageDownloader: ImageDownloader
    private let reloadWidgets: () -> Void
    private let publishDelay: TimeInterval
    private let logger: XCGLogger
    private let queue = DispatchQueue(label: "com.jayprajapati.articles.widgetSync", qos: .utility)

    private var latest: [Article] = []
    private var saved: [Article] = []
    private var lastOpened: Article?
    private var showLastOpenedFirst = false
    private var pendingPublish: DispatchWorkItem?
    private var inFlightImageIDs: Set<String> = []

    init(
        store: SharedArticleStore,
        defaults: UserDefaults = .standard,
        imageDownloader: @escaping ImageDownloader = WidgetSyncManager.downloadDownsampledImage,
        reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSyncManager.widgetKind) },
        publishDelay: TimeInterval = 0.3,
        logger: XCGLogger
    ) {
        self.store = store
        self.defaults = defaults
        self.imageDownloader = imageDownloader
        self.reloadWidgets = reloadWidgets
        self.publishDelay = publishDelay
        self.logger = logger
        lastOpened = Self.loadLastOpened(from: defaults)
    }

    // MARK: - WidgetSyncManagerProtocol

    func updateLatestArticles(_ articles: [Article]) {
        queue.async {
            self.latest = articles
            self.schedulePublish()
        }
    }

    func updateSavedArticles(_ articles: [Article]) {
        queue.async {
            self.saved = articles
            self.schedulePublish()
        }
    }

    func updateLastOpenedArticle(_ article: Article) {
        queue.async {
            guard article.identifier != self.lastOpened?.identifier else { return }
            self.lastOpened = article
            self.showLastOpenedFirst = true
            Self.persist(lastOpened: article, in: self.defaults)
            self.schedulePublish()
        }
    }

    // MARK: - List composition (pure, so the tests can pin the order down)

    /// Last opened first, then saved, then latest, without duplicates.
    static func widgetArticles(latest: [Article], saved: [Article], lastOpened: Article? = nil) -> [WidgetArticleData] {
        let savedIDs = Set(saved.map(\.identifier))
        var seen: Set<String> = []
        var result: [WidgetArticleData] = []

        for article in [lastOpened].compactMap({ $0 }) + saved + latest {
            let id = article.identifier
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            result.append(WidgetArticleData(
                id: id,
                title: article.title ?? article.description ?? untitled,
                sourceName: article.source?.name,
                dateString: ArticleDateFormatter.displayString(from: article.publishedAt),
                webURL: article.url,
                imageURL: article.urlToImage,
                isSaved: savedIDs.contains(id)
            ))
            if result.count == maxArticles { break }
        }
        return result
    }

    // MARK: - Publishing

    private func schedulePublish() {
        pendingPublish?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.publish() }
        pendingPublish = work
        queue.asyncAfter(deadline: .now() + publishDelay, execute: work)
    }

    private func publish() {
        pendingPublish = nil
        guard store.isAvailable else {
            logger.warning("App Group container is unavailable; the widget will not be updated")
            return
        }

        let articles = Self.widgetArticles(latest: latest, saved: saved, lastOpened: lastOpened)
        store.saveArticles(articles)
        if showLastOpenedFirst {
            // Bring the widget back to the article just read; browsing with
            // the widget's own buttons is otherwise left alone.
            store.setCurrentIndex(0)
            showLastOpenedFirst = false
        }
        logger.debug("Published \(articles.count) article(s) to the widget")
        reloadWidgets()
        downloadMissingImages(for: articles)
    }

    private func downloadMissingImages(for articles: [WidgetArticleData]) {
        let pending = articles.filter { article in
            !store.hasImage(for: article.id) && !inFlightImageIDs.contains(article.id) && article.imageURL != nil
        }
        guard !pending.isEmpty else { return }

        let group = DispatchGroup()
        var downloadedAny = false

        for article in pending {
            guard let urlString = article.imageURL, let url = URL(string: urlString) else { continue }
            inFlightImageIDs.insert(article.id)
            group.enter()
            imageDownloader(url) { [weak self] data in
                guard let self else { return }
                self.queue.async {
                    self.inFlightImageIDs.remove(article.id)
                    // Only keep images for articles that are still listed.
                    if let data, self.store.loadArticles().contains(where: { $0.id == article.id }) {
                        self.store.saveImageData(data, for: article.id)
                        downloadedAny = true
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: queue) { [weak self] in
            guard let self, downloadedAny else { return }
            self.reloadWidgets()
        }
    }

    // MARK: - Last opened persistence

    private static func loadLastOpened(from defaults: UserDefaults) -> Article? {
        guard let data = defaults.data(forKey: AppConstants.Widget.lastOpenedArticleKey) else { return nil }
        return try? JSONDecoder().decode(Article.self, from: data)
    }

    private static func persist(lastOpened article: Article, in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(article) else { return }
        defaults.set(data, forKey: AppConstants.Widget.lastOpenedArticleKey)
    }

    // MARK: - Default image downloader

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = AppConstants.Network.requestTimeout
        configuration.timeoutIntervalForResource = AppConstants.Network.resourceTimeout
        return URLSession(configuration: configuration)
    }()

    /// Fetches the image and re-encodes it as a small JPEG. Feed images are
    /// often several megapixels, far more than a widget can decode.
    static func downloadDownsampledImage(from url: URL, completion: @escaping (Data?) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            guard let data, !data.isEmpty else {
                completion(nil)
                return
            }
            completion(downsampledJPEG(from: data))
        }.resume()
    }

    static func downsampledJPEG(from data: Data, maxPixelSize: Int = 800) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
