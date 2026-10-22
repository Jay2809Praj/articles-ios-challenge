import Cache
import Foundation
import Kingfisher
import XCGLogger

/// Internal representation of a saved article and its cached image footprint.
struct SavedArticleRecord: Codable, Equatable {
    let article: Article
    let savedAt: Date
    var imageByteSize: Int64
    var articleByteSize: Int64

    var totalByteSize: Int64 {
        articleByteSize + imageByteSize
    }

    init(article: Article, savedAt: Date = Date(), imageByteSize: Int64 = 0) {
        self.article = article
        self.savedAt = savedAt
        self.imageByteSize = imageByteSize
        if let data = try? JSONEncoder().encode(article) {
            self.articleByteSize = Int64(data.count)
        } else {
            self.articleByteSize = 1024
        }
    }
}

/// Disk-backed, thread-safe implementation of `FavoritesManagerProtocol` built on the
/// `Cache` pod and Kingfisher.
///
/// Articles are persisted with their full text content and cached image data so that
/// they remain 100% available offline even after force quitting and relaunching the app.
/// A strict 50 MB storage limit is enforced using a Least-Recently-Used (LRU) / oldest-first
/// eviction strategy.
final class FavoritesManager: FavoritesManagerProtocol {
    private let storage: Storage<String, [SavedArticleRecord]>?
    private let defaults: UserDefaults
    private let logger: XCGLogger
    private let legacyKey = AppConstants.Favorites.storageKey
    private let storageKey = AppConstants.SavedArticles.recordsKey
    let storageLimitBytes: Int64

    private let lock = NSRecursiveLock()
    private let persistenceQueue = DispatchQueue(label: "com.jayprajapati.articles.savedPersistence", qos: .utility)
    private var records: [SavedArticleRecord] = []

    /// Injection hooks for unit testing image caching without network requests.
    var imageDownloader: ((URL, @escaping (Int64) -> Void) -> Void)?
    var imageRemover: ((URL) -> Void)?

    init(
        defaults: UserDefaults = .standard,
        storageName: String = AppConstants.SavedArticles.storageName,
        storageLimitBytes: Int64 = AppConstants.SavedArticles.maxStorageBytes,
        logger: XCGLogger = LoggerFactory.makeLogger()
    ) {
        self.defaults = defaults
        self.storageLimitBytes = storageLimitBytes
        self.logger = logger

        do {
            self.storage = try Storage(
                diskConfig: DiskConfig(name: storageName, expiry: .never),
                memoryConfig: MemoryConfig(expiry: .never, countLimit: 1, totalCostLimit: 0),
                transformer: TransformerFactory.forCodable(ofType: [SavedArticleRecord].self)
            )
        } catch {
            self.storage = nil
            logger.error("Saved articles storage could not be opened: \(error)")
        }

        loadPersistedRecords()
    }

    // MARK: - FavoritesManagerProtocol

    func isSaved(_ article: Article) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains(where: { $0.article.identifier == article.identifier })
    }

    func save(_ article: Article) {
        let shouldCacheImage: Bool = {
            lock.lock()
            defer { lock.unlock() }

            // If already saved, update savedAt timestamp and persist
            if let index = records.firstIndex(where: { $0.article.identifier == article.identifier }) {
                let existing = records[index]
                let updated = SavedArticleRecord(article: article, savedAt: Date(), imageByteSize: existing.imageByteSize)
                records.remove(at: index)
                records.insert(updated, at: 0)
                persistRecords()
                notifyChange()
                return false
            }

            let newRecord = SavedArticleRecord(article: article, savedAt: Date(), imageByteSize: 0)

            // Enforce 50 MB storage limit before adding
            enforceLimit(freeing: newRecord.totalByteSize)

            records.insert(newRecord, at: 0)
            persistRecords()
            notifyChange()
            return true
        }()

        if shouldCacheImage {
            // Cache image to disk for offline access without holding lock
            cacheImageForOffline(article: article)
        }
    }

    func remove(_ article: Article) {
        lock.lock()
        defer { lock.unlock() }

        guard let index = records.firstIndex(where: { $0.article.identifier == article.identifier }) else { return }
        let removed = records.remove(at: index)
        persistRecords()
        cleanupImage(for: removed.article)
        notifyChange()
    }

    @discardableResult
    func toggleSave(_ article: Article) -> Bool {
        if isSaved(article) {
            remove(article)
            return false
        } else {
            save(article)
            return true
        }
    }

    func savedArticles() -> [Article] {
        lock.lock()
        defer { lock.unlock() }
        return records.map(\.article)
    }

    var totalStorageBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return records.reduce(0) { $0 + $1.totalByteSize }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        for record in records {
            cleanupImage(for: record.article)
        }
        records.removeAll()
        try? storage?.removeAll()
        syncLegacyDefaults()
        notifyChange()
    }

    // MARK: - Internal Helpers

    private func enforceLimit(freeing neededBytes: Int64) {
        var currentTotal = records.reduce(0) { $0 + $1.totalByteSize }

        while currentTotal + neededBytes > storageLimitBytes && !records.isEmpty {
            // Evict oldest saved article (LRU)
            guard let (oldestIndex, oldestRecord) = records.enumerated().min(by: { $0.element.savedAt < $1.element.savedAt }) else {
                break
            }
            records.remove(at: oldestIndex)
            currentTotal -= oldestRecord.totalByteSize
            cleanupImage(for: oldestRecord.article)
            logger.info("Evicted oldest saved article '\(oldestRecord.article.title ?? "")' to stay within 50MB limit")
        }
    }

    private func cacheImageForOffline(article: Article) {
        guard let urlString = article.urlToImage, let url = URL(string: urlString) else { return }

        if let imageDownloader = self.imageDownloader {
            imageDownloader(url) { [weak self] downloadedBytes in
                self?.updateImageByteSize(for: article.identifier, size: downloadedBytes)
            }
            return
        }

        // Production Kingfisher offline caching dispatches callback to persistence queue
        KingfisherManager.shared.retrieveImage(
            with: url,
            options: [
                .cacheOriginalImage,
                .callbackQueue(.dispatch(persistenceQueue))
            ]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let value):
                let size: Int64
                if let data = value.data() {
                    size = Int64(data.count)
                } else if let cgImage = value.image.cgImage {
                    size = Int64(cgImage.bytesPerRow * cgImage.height)
                } else {
                    size = 120_000
                }
                self.updateImageByteSize(for: article.identifier, size: size)
            case .failure(let error):
                self.logger.warning("Failed to prefetch image for offline storage: \(error)")
            }
        }
    }

    private func updateImageByteSize(for identifier: String, size: Int64) {
        lock.lock()
        defer { lock.unlock() }

        guard let index = records.firstIndex(where: { $0.article.identifier == identifier }) else { return }
        records[index].imageByteSize = size
        persistRecords()
    }

    private func cleanupImage(for article: Article) {
        guard let urlString = article.urlToImage, let url = URL(string: urlString) else { return }

        if let imageRemover = self.imageRemover {
            imageRemover(url)
        } else {
            persistenceQueue.async {
                ImageCache.default.removeImage(forKey: url.absoluteString, fromDisk: true)
            }
        }
    }

    private func loadPersistedRecords() {
        lock.lock()
        defer { lock.unlock() }

        if let storage, let loaded = try? storage.object(forKey: storageKey) {
            records = loaded
            logger.debug("Loaded \(records.count) saved article(s) from disk cache")
        } else {
            records = []
        }

        syncLegacyDefaults()
    }

    private func persistRecords() {
        do {
            try storage?.setObject(records, forKey: storageKey)
        } catch {
            logger.error("Failed to persist saved articles: \(error)")
        }
        syncLegacyDefaults()
    }

    private func syncLegacyDefaults() {
        let identifiers = records.map(\.article.identifier).sorted()
        defaults.set(identifiers, forKey: legacyKey)
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: AppConstants.SavedArticles.didChangeNotification,
                object: nil
            )
        }
    }
}

