import Cache
import Foundation
import XCGLogger

/// Internal representation of a saved article and its stored image footprint.
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

/// What the storage limit took away, so the UI can tell the user.
struct SavedArticlesEviction: Equatable {
    enum Reason: Equatable {
        /// Older saved articles were removed to make room within the limit.
        case storageFull
        /// A single article, image included, is larger than the whole limit.
        case articleTooLarge
    }

    let reason: Reason
    /// Titles of the removed articles, oldest first; untitled ones fall back
    /// to their description.
    let titles: [String]
}

/// Disk-backed, thread-safe implementation of `FavoritesManagerProtocol` built on the
/// `Cache` pod for the article records and `SavedImageStore` for the images.
///
/// Articles are persisted with their full text content, and their images are
/// downloaded into the app's own storage so they stay available offline after
/// force quitting, relaunching, or weeks of not opening the app. A strict
/// 50 MB storage limit is enforced using an oldest-saved-first eviction
/// strategy, counting the real size of every image file on disk. The budget is
/// re-enforced whenever an image download completes.
final class FavoritesManager: FavoritesManagerProtocol {
    typealias ImageDownloader = (URL, @escaping (Data?) -> Void) -> Void

    private let storage: Storage<String, [SavedArticleRecord]>?
    private let defaults: UserDefaults
    private let imageStore: SavedImageStoreProtocol
    private let imageDownloader: ImageDownloader
    private let widgetSync: WidgetSyncManagerProtocol?
    private let logger: XCGLogger
    private let legacyKey = AppConstants.Favorites.storageKey
    private let storageKey = AppConstants.SavedArticles.recordsKey
    let storageLimitBytes: Int64

    private let lock = NSRecursiveLock()
    private var records: [SavedArticleRecord] = []
    private var downloadingImageIDs: Set<String> = []
    /// Evictions collected while the lock is held, reported once it is released.
    private var pendingEvictions: [SavedArticlesEviction] = []

    init(
        defaults: UserDefaults = .standard,
        storageName: String = AppConstants.SavedArticles.storageName,
        storageLimitBytes: Int64 = AppConstants.SavedArticles.maxStorageBytes,
        imageStore: SavedImageStoreProtocol = SavedImageStore(),
        imageDownloader: @escaping ImageDownloader = FavoritesManager.downloadImage,
        widgetSync: WidgetSyncManagerProtocol? = nil,
        logger: XCGLogger = LoggerFactory.makeLogger()
    ) {
        self.defaults = defaults
        self.storageLimitBytes = storageLimitBytes
        self.imageStore = imageStore
        self.imageDownloader = imageDownloader
        self.widgetSync = widgetSync
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
        reconcileImages()
        widgetSync?.updateSavedArticles(savedArticles())
    }

    // MARK: - FavoritesManagerProtocol

    func isSaved(_ article: Article) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return records.contains(where: { $0.article.identifier == article.identifier })
    }

    func save(_ article: Article) {
        let needsImage: Bool = {
            lock.lock()
            defer { lock.unlock() }

            // Already saved: move it to the front and keep its image.
            if let index = records.firstIndex(where: { $0.article.identifier == article.identifier }) {
                let existing = records[index]
                let updated = SavedArticleRecord(article: article, savedAt: Date(), imageByteSize: existing.imageByteSize)
                records.remove(at: index)
                records.insert(updated, at: 0)
                persistRecords()
                notifyChange()
                return existing.imageByteSize == 0
            }

            let newRecord = SavedArticleRecord(article: article, savedAt: Date(), imageByteSize: 0)

            // Enforce the storage limit before adding
            enforceLimit(freeing: newRecord.totalByteSize)

            records.insert(newRecord, at: 0)
            persistRecords()
            notifyChange()
            return true
        }()

        reportPendingEvictions()
        if needsImage {
            downloadImageIfNeeded(for: article)
        }
    }

    func remove(_ article: Article) {
        lock.lock()
        defer { lock.unlock() }

        guard let index = records.firstIndex(where: { $0.article.identifier == article.identifier }) else { return }
        let removed = records.remove(at: index)
        persistRecords()
        imageStore.remove(for: removed.article.identifier)
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

    func savedImageURL(for article: Article) -> URL? {
        guard isSaved(article) else { return nil }
        return imageStore.imageURL(for: article.identifier)
    }

    var totalStorageBytes: Int64 {
        lock.lock()
        defer { lock.unlock() }
        return records.reduce(0) { $0 + $1.totalByteSize }
    }

    func clearAll() {
        lock.lock()
        defer { lock.unlock() }

        records.removeAll()
        imageStore.removeAll()
        try? storage?.removeAll()
        syncLegacyDefaults()
        notifyChange()
    }

    // MARK: - Budget

    private func enforceLimit(freeing neededBytes: Int64 = 0) {
        var currentTotal = records.reduce(0) { $0 + $1.totalByteSize }
        var evictedTitles: [String] = []

        while currentTotal + neededBytes > storageLimitBytes && !records.isEmpty {
            // Evict oldest saved article first
            guard let (oldestIndex, oldestRecord) = records.enumerated().min(by: { $0.element.savedAt < $1.element.savedAt }) else {
                break
            }
            records.remove(at: oldestIndex)
            currentTotal -= oldestRecord.totalByteSize
            imageStore.remove(for: oldestRecord.article.identifier)
            evictedTitles.append(Self.displayTitle(of: oldestRecord.article))
            logger.info("Evicted oldest saved article '\(oldestRecord.article.title ?? "")' to stay within the storage limit")
        }

        if !evictedTitles.isEmpty {
            pendingEvictions.append(SavedArticlesEviction(reason: .storageFull, titles: evictedTitles))
        }
    }

    /// Removes a single record whose total size alone exceeds the storage limit.
    private func evictOversizedRecord(identifier: String) {
        guard let index = records.firstIndex(where: { $0.article.identifier == identifier }) else { return }
        let record = records[index]
        if record.totalByteSize > storageLimitBytes {
            records.remove(at: index)
            imageStore.remove(for: record.article.identifier)
            pendingEvictions.append(SavedArticlesEviction(reason: .articleTooLarge, titles: [Self.displayTitle(of: record.article)]))
            logger.warning("Removed article '\(record.article.title ?? "")' because its total size (\(record.totalByteSize) bytes) exceeds the \(storageLimitBytes) byte limit")
        }
    }

    // MARK: - Images

    /// Fetches the article's image into the app's own storage, once.
    private func downloadImageIfNeeded(for article: Article) {
        guard let urlString = article.urlToImage, let url = URL(string: urlString) else { return }
        let identifier = article.identifier

        let shouldStart: Bool = {
            lock.lock()
            defer { lock.unlock() }
            return downloadingImageIDs.insert(identifier).inserted
        }()
        guard shouldStart else { return }

        imageDownloader(url) { [weak self] data in
            self?.storeDownloadedImage(data, for: identifier)
        }
    }

    private func storeDownloadedImage(_ data: Data?, for identifier: String) {
        lock.lock()
        defer {
            lock.unlock()
            reportPendingEvictions()
        }

        downloadingImageIDs.remove(identifier)
        // The article may have been removed while the download was running.
        guard let index = records.firstIndex(where: { $0.article.identifier == identifier }) else { return }
        guard let data, !data.isEmpty else {
            logger.warning("Image for saved article '\(records[index].article.title ?? "")' could not be downloaded; it stays saved without one")
            return
        }

        let bytes = imageStore.save(data, for: identifier)
        guard bytes > 0 else {
            logger.error("Image for saved article '\(records[index].article.title ?? "")' could not be written to disk")
            return
        }
        records[index].imageByteSize = bytes

        // Re-enforce the storage limit now that the true image size is known.
        evictOversizedRecord(identifier: identifier)
        enforceLimit()

        persistRecords()
        notifyChange()
    }

    /// Brings the records in line with what is actually on disk: sizes are
    /// re-read from the files, and images that are missing (a download that
    /// never finished, for instance) are fetched again.
    private func reconcileImages() {
        let missing: [Article] = {
            lock.lock()
            defer { lock.unlock() }

            var changed = false
            for index in records.indices {
                let actual = imageStore.byteSize(for: records[index].article.identifier)
                if records[index].imageByteSize != actual {
                    records[index].imageByteSize = actual
                    changed = true
                }
            }
            if changed {
                enforceLimit()
                persistRecords()
            }
            return records.filter { $0.imageByteSize == 0 && $0.article.urlToImage != nil }.map(\.article)
        }()

        reportPendingEvictions()
        for article in missing {
            downloadImageIfNeeded(for: article)
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = AppConstants.Network.requestTimeout
        configuration.timeoutIntervalForResource = AppConstants.Network.resourceTimeout
        return URLSession(configuration: configuration)
    }()

    static func downloadImage(from url: URL, completion: @escaping (Data?) -> Void) {
        session.dataTask(with: url) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200..<300).contains(status), let data, !data.isEmpty else {
                completion(nil)
                return
            }
            completion(data)
        }.resume()
    }

    // MARK: - Eviction reporting

    private static func displayTitle(of article: Article) -> String {
        article.title ?? article.description ?? "Untitled article"
    }

    /// Posts one notification per eviction collected since the last call.
    /// Never called while the lock is held, so observers may call back in.
    private func reportPendingEvictions() {
        let evictions: [SavedArticlesEviction] = {
            lock.lock()
            defer { lock.unlock() }
            let pending = pendingEvictions
            pendingEvictions.removeAll()
            return pending
        }()
        guard !evictions.isEmpty else { return }

        for eviction in evictions {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: AppConstants.SavedArticles.didEvictNotification,
                    object: nil,
                    userInfo: [AppConstants.SavedArticles.evictionUserInfoKey: eviction]
                )
            }
        }
    }

    // MARK: - Persistence

    private func loadPersistedRecords() {
        lock.lock()
        defer { lock.unlock() }

        if let storage, let loaded = try? storage.object(forKey: storageKey) {
            records = loaded
            logger.debug("Loaded \(records.count) saved article(s) from disk")
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
        widgetSync?.updateSavedArticles(savedArticles())
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: AppConstants.SavedArticles.didChangeNotification,
                object: nil
            )
        }
    }
}
