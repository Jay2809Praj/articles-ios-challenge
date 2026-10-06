@testable import Articles
import Foundation
import XCGLogger

final class MockArticlesProvider: ArticlesProviderProtocol {
    var result: Result<[Article], NetworkError> = .success([])
    private(set) var fetchCount = 0

    func fetchArticles() async throws -> [Article] {
        fetchCount += 1
        return try result.get()
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

    func data(from endpoint: Endpoint) async throws -> Data {
        try result.get()
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
