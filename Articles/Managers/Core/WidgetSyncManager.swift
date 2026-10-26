import Foundation
import ImageIO
import UniformTypeIdentifiers
import WidgetKit
import XCGLogger

/// Publishes the app's articles to the widget through `SharedArticleStore`.
///
/// The widget shows saved articles first, then the latest loaded ones, up to
/// `maxArticles`. Each publish writes the list once, asks WidgetKit to reload
/// once, and only then fetches the images that are still missing – each one a
/// single time, downsampled so the extension stays within its memory limit –
/// followed by one more reload when any arrived.
final class WidgetSyncManager: WidgetSyncManagerProtocol {
    typealias ImageDownloader = (URL, @escaping (Data?) -> Void) -> Void

    static let maxArticles = 10
    static let widgetKind = "ArticlesWidget"
    static let untitled = "Untitled article"

    private let store: SharedArticleStore
    private let imageDownloader: ImageDownloader
    private let reloadWidgets: () -> Void
    private let logger: XCGLogger
    private let queue = DispatchQueue(label: "com.jayprajapati.articles.widgetSync", qos: .utility)

    private var latest: [Article] = []
    private var saved: [Article] = []
    private var inFlightImageIDs: Set<String> = []

    init(
        store: SharedArticleStore,
        imageDownloader: @escaping ImageDownloader = WidgetSyncManager.downloadDownsampledImage,
        reloadWidgets: @escaping () -> Void = { WidgetCenter.shared.reloadTimelines(ofKind: WidgetSyncManager.widgetKind) },
        logger: XCGLogger
    ) {
        self.store = store
        self.imageDownloader = imageDownloader
        self.reloadWidgets = reloadWidgets
        self.logger = logger
    }

    // MARK: - WidgetSyncManagerProtocol

    func updateLatestArticles(_ articles: [Article]) {
        queue.async {
            self.latest = articles
            self.publish()
        }
    }

    func updateSavedArticles(_ articles: [Article]) {
        queue.async {
            self.saved = articles
            self.publish()
        }
    }

    // MARK: - Publishing

    /// Saved first, then latest, without duplicates. Pure, so the tests can
    /// pin the order down.
    static func widgetArticles(latest: [Article], saved: [Article]) -> [WidgetArticleData] {
        var seen: Set<String> = []
        var result: [WidgetArticleData] = []

        for (article, isSaved) in saved.map({ ($0, true) }) + latest.map({ ($0, false) }) {
            let id = article.identifier
            guard !id.isEmpty, seen.insert(id).inserted else { continue }
            result.append(WidgetArticleData(
                id: id,
                title: article.title ?? article.description ?? untitled,
                sourceName: article.source?.name,
                dateString: ArticleDateFormatter.displayString(from: article.publishedAt),
                webURL: article.url,
                imageURL: article.urlToImage,
                isSaved: isSaved
            ))
            if result.count == maxArticles { break }
        }
        return result
    }

    private func publish() {
        guard store.isAvailable else {
            logger.warning("App Group container is unavailable; the widget will not be updated")
            return
        }

        let articles = Self.widgetArticles(latest: latest, saved: saved)
        store.saveArticles(articles)
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
