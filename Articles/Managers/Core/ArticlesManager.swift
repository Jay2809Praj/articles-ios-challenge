import Foundation
import XCGLogger

/// Coordinates the provider and the cache so the UI gets the best available
/// list of articles, page by page, without knowing how it was obtained.
///
/// Pages come from the provider while it answers. When it does not, the list
/// on disk takes over and is served in pages of the same size, so the screen
/// behaves the same way offline. The cache always holds every page loaded so
/// far from the network.
///
/// Callers that ask for page 1 while it is loading share that one request,
/// and a page that arrives after the list started over is dropped instead of
/// being glued onto the new list.
final class ArticlesManager: ArticlesManagerProtocol {
    private enum Source {
        case network
        case cache(savedAt: Date, all: [Article])
    }

    private let provider: ArticlesProviderProtocol
    private let cache: ArticlesCacheProtocol
    private let widgetSync: WidgetSyncManagerProtocol?
    private let pageSize: Int
    private let logger: XCGLogger

    private let lock = NSLock()
    private var source: Source = .network
    private var loaded: [Article] = []
    private var pagesLoaded = 0
    private var hasMore = false
    /// Bumped every time the list starts over. A next-page answer that
    /// arrives after that belongs to the old list and is thrown away.
    private var generation = 0
    /// The first-page request in flight, shared by every caller that asks
    /// for page 1 while it runs.
    private var firstPageTask: Task<ArticlesLoadResult, Never>?

    init(
        provider: ArticlesProviderProtocol,
        cache: ArticlesCacheProtocol,
        widgetSync: WidgetSyncManagerProtocol? = nil,
        pageSize: Int = AppConstants.Pagination.pageSize,
        logger: XCGLogger
    ) {
        self.provider = provider
        self.cache = cache
        self.widgetSync = widgetSync
        self.pageSize = pageSize
        self.logger = logger
    }

    // MARK: - ArticlesManagerProtocol

    func cachedArticles() -> ArticlesLoadResult? {
        guard let cached = cache.load(), !cached.articles.isEmpty else { return nil }
        widgetSync?.updateLatestArticles(cached.articles)
        return serveFromCache(cached, error: nil)
    }

    func loadArticles() async -> ArticlesLoadResult {
        let task: Task<ArticlesLoadResult, Never> = lock.withLock {
            if let running = firstPageTask {
                logger.debug("Page 1 is already loading; sharing that request")
                return running
            }
            let task = Task { await self.fetchFirstPage() }
            firstPageTask = task
            return task
        }
        return await task.value
    }

    func loadNextPage() async -> ArticlesLoadResult {
        let (currentSource, nextPage, more, startedIn) = lock.withLock {
            (source, pagesLoaded + 1, hasMore, generation)
        }
        guard more else { return currentResult(error: nil) }

        switch currentSource {
        case .cache(let savedAt, let all):
            // Offline paging: the next slice of what is on disk.
            lock.withLock {
                guard generation == startedIn else { return }
                loaded = Array(all.prefix(nextPage * pageSize))
                pagesLoaded = nextPage
                hasMore = loaded.count < all.count
            }
            logger.debug("Served page \(nextPage) from the cache saved at \(savedAt)")
            return currentResult(error: nil)

        case .network:
            do {
                let page = try await provider.fetchArticles(page: nextPage, pageSize: pageSize)
                let all: [Article]? = lock.withLock {
                    // The list started over while this page was on its way.
                    guard generation == startedIn, pagesLoaded == nextPage - 1 else { return nil }
                    loaded += page.articles
                    pagesLoaded = nextPage
                    hasMore = page.hasMore
                    return loaded
                }
                guard let all else {
                    logger.debug("Dropped page \(nextPage): the list was reloaded meanwhile")
                    return currentResult(error: nil)
                }
                cache.save(all)
                widgetSync?.updateLatestArticles(all)
                return currentResult(error: nil)
            } catch {
                let networkError = (error as? NetworkError) ?? .unknown(description: error.localizedDescription)
                let count = lock.withLock { loaded.count }
                logger.warning("Page \(nextPage) failed (\(networkError)); keeping \(count) loaded article(s)")
                return currentResult(error: networkError)
            }
        }
    }

    func allCachedArticles() -> [Article] {
        cache.load()?.articles ?? []
    }

    // MARK: - Private

    private func fetchFirstPage() async -> ArticlesLoadResult {
        defer { lock.withLock { firstPageTask = nil } }
        do {
            let page = try await provider.fetchArticles(page: 1, pageSize: pageSize)
            lock.withLock {
                generation += 1
                source = .network
                loaded = page.articles
                pagesLoaded = 1
                hasMore = page.hasMore
            }
            // An empty answer is valid, but not worth replacing a usable cache with.
            if !page.articles.isEmpty {
                cache.save(page.articles)
                widgetSync?.updateLatestArticles(page.articles)
            }
            return ArticlesLoadResult(articles: page.articles, origin: .network, error: nil, hasMore: page.hasMore)
        } catch {
            let networkError = (error as? NetworkError) ?? .unknown(description: error.localizedDescription)
            return fallback(for: networkError)
        }
    }

    private func fallback(for error: NetworkError) -> ArticlesLoadResult {
        if let cached = cache.load(), !cached.articles.isEmpty {
            logger.warning("Request failed (\(error)); serving \(cached.articles.count) cached article(s)")
            return serveFromCache(cached, error: error)
        }
        logger.error("Request failed (\(error)) and no cached articles are available")
        lock.withLock {
            generation += 1
            source = .network
            loaded = []
            pagesLoaded = 0
            hasMore = false
        }
        return ArticlesLoadResult(articles: [], origin: .network, error: error, hasMore: false)
    }

    /// Starts paging through the cached list from its first page.
    private func serveFromCache(_ cached: CachedArticles, error: NetworkError?) -> ArticlesLoadResult {
        lock.withLock {
            generation += 1
            source = .cache(savedAt: cached.savedAt, all: cached.articles)
            loaded = Array(cached.articles.prefix(pageSize))
            pagesLoaded = 1
            hasMore = loaded.count < cached.articles.count
        }
        return currentResult(error: error)
    }

    private func currentResult(error: NetworkError?) -> ArticlesLoadResult {
        lock.withLock {
            let origin: ArticlesOrigin
            switch source {
            case .network: origin = .network
            case .cache(let savedAt, _): origin = .cache(savedAt: savedAt)
            }
            return ArticlesLoadResult(articles: loaded, origin: origin, error: error, hasMore: hasMore)
        }
    }
}
