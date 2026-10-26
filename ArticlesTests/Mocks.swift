@testable import Articles
import Foundation
import XCGLogger

/// Plays a paginating server over an in-memory feed.
final class MockArticlesProvider: ArticlesProviderProtocol {
    var feed: Result<[Article], NetworkError> = .success([])
    /// Pages that fail with the given error instead of answering.
    var failingPages: [Int: NetworkError] = [:]
    private(set) var requestedPages: [Int] = []

    func fetchArticles(page: Int, pageSize: Int) async throws -> ArticlesPage {
        requestedPages.append(page)
        if let error = failingPages[page] { throw error }
        let all = try feed.get()
        let start = min((page - 1) * pageSize, all.count)
        let articles = Array(all[start..<min(start + pageSize, all.count)])
        return ArticlesPage(articles: articles, page: page, hasMore: start + articles.count < all.count)
    }
}

final class MockArticlesCache: ArticlesCacheProtocol {
    var stored: CachedArticles?

    func save(_ articles: [Article]) {
        stored = CachedArticles(articles: articles, savedAt: Date())
    }

    func load() -> CachedArticles? {
        stored
    }

    func clear() {
        stored = nil
    }
}

final class MockNetworkClient: NetworkClientProtocol {
    var result: Result<Data, NetworkError> = .success(Data())
    private(set) var requestCount = 0

    func data(from endpoint: Endpoint) async throws -> Data {
        requestCount += 1
        return try result.get()
    }
}

final class MockReachabilityProvider: ReachabilityProviderProtocol {
    var isReachable = true
    var onReachabilityChange: ((Bool) -> Void)?
    private(set) var isMonitoring = false

    func startMonitoring() {
        isMonitoring = true
    }

    func stopMonitoring() {
        isMonitoring = false
    }

    func simulate(reachable: Bool) {
        isReachable = reachable
        onReachabilityChange?(reachable)
    }
}

extension XCGLogger {
    /// A logger that prints nothing, for tests.
    static var silent: XCGLogger {
        let logger = XCGLogger(identifier: "tests", includeDefaultDestinations: false)
        logger.outputLevel = .none
        return logger
    }
}

extension Article {
    static func sample(
        title: String? = "Title",
        description: String? = "Description",
        url: String? = "https://example.com/article",
        author: String? = "Author"
    ) -> Article {
        Article(
            source: ArticleSource(id: nil, name: "Source"),
            author: author,
            title: title,
            description: description,
            url: url,
            urlToImage: "https://example.com/image.jpg",
            publishedAt: "2025-03-07T11:00:59Z",
            content: "Content"
        )
    }
}

final class MockWidgetSyncManager: WidgetSyncManagerProtocol {
    private(set) var latestUpdates: [[Article]] = []
    private(set) var savedUpdates: [[Article]] = []
    private(set) var lastOpenedUpdates: [Article] = []

    func updateLatestArticles(_ articles: [Article]) {
        latestUpdates.append(articles)
    }

    func updateSavedArticles(_ articles: [Article]) {
        savedUpdates.append(articles)
    }

    func updateLastOpenedArticle(_ article: Article) {
        lastOpenedUpdates.append(article)
    }
}

extension SharedArticleStore {
    /// A store in a fresh temporary directory, isolated from the App Group.
    static func temporary() -> SharedArticleStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SharedArticleStoreTests-\(UUID().uuidString)", isDirectory: true)
        return SharedArticleStore(containerURL: url)
    }
}

extension Array where Element == Article {
    /// `count` distinct sample articles titled "Article 1" … "Article N".
    static func samples(_ count: Int) -> [Article] {
        (1...Swift.max(count, 1)).prefix(count).map { Article.sample(title: "Article \($0)", url: "https://example.com/\($0)") }
    }
}

/// In-memory stand-in for `SavedImageStore`.
final class MockSavedImageStore: SavedImageStoreProtocol {
    private let lock = NSLock()
    private var files: [String: Data] = [:]
    private(set) var removed: [String] = []
    private(set) var removeAllCount = 0
    private let baseURL = URL(fileURLWithPath: "/mock/saved-images")

    var storedIDs: [String] { lock.withLock { Array(files.keys) } }

    func imageURL(for articleID: String) -> URL? {
        lock.withLock { files[articleID] == nil ? nil : baseURL.appendingPathComponent(articleID) }
    }

    @discardableResult
    func save(_ data: Data, for articleID: String) -> Int64 {
        lock.withLock {
            files[articleID] = data
            return Int64(data.count)
        }
    }

    func byteSize(for articleID: String) -> Int64 {
        lock.withLock { Int64(files[articleID]?.count ?? 0) }
    }

    func remove(for articleID: String) {
        lock.withLock {
            files[articleID] = nil
            removed.append(articleID)
        }
    }

    func removeAll() {
        lock.withLock {
            files = [:]
            removeAllCount += 1
        }
    }
}
