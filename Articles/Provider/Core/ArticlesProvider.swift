import Foundation
import XCGLogger

/// Fetches and decodes the articles feed, one page at a time.
///
/// The mock API has no paging of its own: it returns the whole feed in one
/// payload. This provider therefore plays the server's part. A request for
/// page 1 downloads the feed and keeps it as the snapshot that later pages are
/// cut from, each answered after a short simulated latency, so everything
/// above this layer sees a paginated API and nothing else.
final class ArticlesProvider: ArticlesProviderProtocol {
    typealias Sleep = (TimeInterval) async -> Void

    private let client: NetworkClientProtocol
    private let decoder: JSONDecoder
    private let simulatedLatency: TimeInterval
    private let sleep: Sleep
    private let logger: XCGLogger

    private let lock = NSLock()
    private var snapshot: [Article]?

    init(
        client: NetworkClientProtocol,
        decoder: JSONDecoder = JSONDecoder(),
        simulatedLatency: TimeInterval = AppConstants.Pagination.simulatedLatency,
        sleep: @escaping Sleep = { seconds in try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) },
        logger: XCGLogger
    ) {
        self.client = client
        self.decoder = decoder
        self.simulatedLatency = simulatedLatency
        self.sleep = sleep
        self.logger = logger
    }

    func fetchArticles(page: Int, pageSize: Int) async throws -> ArticlesPage {
        guard page >= 1, pageSize >= 1 else {
            return ArticlesPage(articles: [], page: page, hasMore: false)
        }

        let feed: [Article]
        if page == 1 || currentSnapshot == nil {
            feed = try await downloadFeed()
            currentSnapshot = feed
        } else {
            // A later page of the feed we already hold; take as long as a
            // server round trip would.
            feed = currentSnapshot ?? []
            await sleep(simulatedLatency)
        }

        let start = min((page - 1) * pageSize, feed.count)
        let articles = Array(feed[start..<min(start + pageSize, feed.count)])
        let hasMore = start + articles.count < feed.count
        logger.debug("Serving page \(page): \(articles.count) article(s), more: \(hasMore)")
        return ArticlesPage(articles: articles, page: page, hasMore: hasMore)
    }

    // MARK: - Private

    private var currentSnapshot: [Article]? {
        get { lock.withLock { snapshot } }
        set { lock.withLock { snapshot = newValue } }
    }

    private func downloadFeed() async throws -> [Article] {
        let data = try await client.data(from: .articles)

        let response: ArticlesResponse
        do {
            response = try decoder.decode(ArticlesResponse.self, from: data)
        } catch {
            logger.error("Articles payload is not valid JSON for the expected schema: \(error)")
            throw NetworkError.invalidResponse
        }

        let articles = response.articles.filter(\.hasDisplayableContent)
        let dropped = response.articles.count - articles.count
        if dropped > 0 {
            logger.warning("Dropped \(dropped) article(s) without any displayable content")
        }
        logger.debug("Downloaded \(articles.count) article(s)")
        return articles
    }
}
