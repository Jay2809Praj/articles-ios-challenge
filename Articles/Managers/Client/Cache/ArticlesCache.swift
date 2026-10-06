import Cache
import Foundation
import XCGLogger

/// Disk-backed implementation of `ArticlesCacheProtocol` built on the Cache pod.
///
/// The list never expires: stale articles are more useful than an empty screen
/// when the device is offline. Storage failures are logged and swallowed – a
/// broken cache must never take the app down with it.
final class ArticlesCache: ArticlesCacheProtocol {
    private let storage: Storage<String, CachedArticles>?
    private let logger: XCGLogger
    private let key = AppConstants.Cache.articlesKey

    init(logger: XCGLogger) {
        self.logger = logger
        do {
            storage = try Storage(
                diskConfig: DiskConfig(name: AppConstants.Cache.storageName, expiry: .never),
                memoryConfig: MemoryConfig(expiry: .never, countLimit: 1, totalCostLimit: 0),
                transformer: TransformerFactory.forCodable(ofType: CachedArticles.self)
            )
        } catch {
            storage = nil
            logger.error("Articles cache could not be opened: \(error)")
        }
    }

    func save(_ articles: [Article]) {
        do {
            try storage?.setObject(CachedArticles(articles: articles, savedAt: Date()), forKey: key)
            logger.debug("Cached \(articles.count) article(s)")
        } catch {
            logger.error("Failed to cache articles: \(error)")
        }
    }

    func load() -> CachedArticles? {
        guard let storage else { return nil }
        do {
            guard try storage.existsObject(forKey: key) else { return nil }
            return try storage.object(forKey: key)
        } catch {
            // Most likely the entity changed shape between app versions.
            logger.warning("Cached articles are unreadable and will be discarded: \(error)")
            clear()
            return nil
        }
    }

    func clear() {
        do {
            try storage?.removeAll()
        } catch {
            logger.error("Failed to clear the articles cache: \(error)")
        }
    }
}
