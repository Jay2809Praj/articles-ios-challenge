@testable import Articles
import XCTest

/// The offline behaviour the challenge tests explicitly, plus paging.
final class ArticlesManagerTests: XCTestCase {
    private var provider: MockArticlesProvider!
    private var cache: MockArticlesCache!
    private var widgetSync: MockWidgetSyncManager!
    private var manager: ArticlesManager!

    override func setUp() {
        super.setUp()
        provider = MockArticlesProvider()
        cache = MockArticlesCache()
        widgetSync = MockWidgetSyncManager()
        manager = ArticlesManager(provider: provider, cache: cache, widgetSync: widgetSync, pageSize: 10, logger: .silent)
    }

    // MARK: - First page

    func testSuccessReturnsNetworkArticlesAndCachesThem() async {
        provider.feed = .success([.sample(title: "Fresh")])

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.map(\.title), ["Fresh"])
        XCTAssertEqual(result.origin, .network)
        XCTAssertNil(result.error)
        XCTAssertFalse(result.hasMore)
        XCTAssertEqual(cache.stored?.articles.map(\.title), ["Fresh"])
    }

    func testFirstPageIsOnePageOfTheFeed() async {
        provider.feed = .success(.samples(25))

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.count, 10)
        XCTAssertEqual(result.articles.last?.title, "Article 10")
        XCTAssertTrue(result.hasMore)
        XCTAssertEqual(provider.requestedPages, [1])
        XCTAssertEqual(cache.stored?.articles.count, 10, "Only what was loaded is on disk")
    }

    func testFailureFallsBackToCachedArticles() async {
        cache.save([.sample(title: "Saved")])
        provider.feed = .failure(.offline)

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.map(\.title), ["Saved"])
        XCTAssertTrue(result.isStale)
        XCTAssertEqual(result.error, .offline)
        XCTAssertFalse(result.hasMore)
    }

    func testInvalidResponseAlsoFallsBackToCache() async {
        cache.save([.sample(title: "Saved")])
        provider.feed = .failure(.invalidResponse)

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.count, 1)
        XCTAssertEqual(result.error, .invalidResponse)
    }

    func testFailureWithoutCacheReturnsErrorAndNoArticles() async {
        provider.feed = .failure(.timedOut)

        let result = await manager.loadArticles()

        XCTAssertTrue(result.articles.isEmpty)
        XCTAssertEqual(result.error, .timedOut)
        XCTAssertFalse(result.hasMore)
    }

    func testEmptyResponseDoesNotOverwriteCache() async {
        cache.save([.sample(title: "Saved")])
        provider.feed = .success([])

        _ = await manager.loadArticles()

        XCTAssertEqual(cache.stored?.articles.map(\.title), ["Saved"])
    }

    // MARK: - Next pages

    func testNextPageAppendsAndCachesEverythingLoaded() async {
        provider.feed = .success(.samples(25))
        _ = await manager.loadArticles()

        let page2 = await manager.loadNextPage()
        XCTAssertEqual(page2.articles.count, 20)
        XCTAssertEqual(page2.articles.last?.title, "Article 20")
        XCTAssertTrue(page2.hasMore)
        XCTAssertEqual(cache.stored?.articles.count, 20)

        let page3 = await manager.loadNextPage()
        XCTAssertEqual(page3.articles.count, 25)
        XCTAssertFalse(page3.hasMore)
        XCTAssertEqual(provider.requestedPages, [1, 2, 3])
        XCTAssertEqual(cache.stored?.articles.count, 25)
    }

    func testNextPageAfterTheLastOneChangesNothing() async {
        provider.feed = .success(.samples(5))
        _ = await manager.loadArticles()

        let result = await manager.loadNextPage()

        XCTAssertEqual(result.articles.count, 5)
        XCTAssertFalse(result.hasMore)
        XCTAssertEqual(provider.requestedPages, [1], "No request when the provider said there is nothing more")
    }

    func testFailedNextPageKeepsWhatIsLoadedAndReportsTheError() async {
        provider.feed = .success(.samples(25))
        provider.failingPages = [2: .timedOut]
        _ = await manager.loadArticles()

        let result = await manager.loadNextPage()

        XCTAssertEqual(result.articles.count, 10)
        XCTAssertEqual(result.error, .timedOut)
        XCTAssertTrue(result.hasMore, "The page can be retried")
        XCTAssertEqual(cache.stored?.articles.count, 10)

        provider.failingPages = [:]
        let retried = await manager.loadNextPage()
        XCTAssertEqual(retried.articles.count, 20)
        XCTAssertNil(retried.error)
    }

    func testReloadingTheFirstPageDiscardsLaterPages() async {
        provider.feed = .success(.samples(25))
        _ = await manager.loadArticles()
        _ = await manager.loadNextPage()

        let reloaded = await manager.loadArticles()

        XCTAssertEqual(reloaded.articles.count, 10)
        XCTAssertTrue(reloaded.hasMore)
        XCTAssertEqual(provider.requestedPages, [1, 2, 1])
    }

    // MARK: - Offline paging

    func testCachedArticlesAreServedInPagesSynchronously() {
        XCTAssertNil(manager.cachedArticles())

        cache.save(.samples(23))
        let first = manager.cachedArticles()

        XCTAssertEqual(first?.articles.count, 10)
        XCTAssertEqual(first?.isStale, true)
        XCTAssertEqual(first?.hasMore, true)
    }

    func testOfflineNextPagesComeFromTheCache() async {
        cache.save(.samples(23))
        provider.feed = .failure(.offline)
        let first = await manager.loadArticles()
        XCTAssertEqual(first.articles.count, 10)
        XCTAssertEqual(first.error, .offline)

        let second = await manager.loadNextPage()
        XCTAssertEqual(second.articles.count, 20)
        XCTAssertTrue(second.isStale)
        XCTAssertNil(second.error)
        XCTAssertTrue(second.hasMore)

        let third = await manager.loadNextPage()
        XCTAssertEqual(third.articles.count, 23)
        XCTAssertFalse(third.hasMore)
        XCTAssertEqual(provider.requestedPages, [1], "Cache pages never hit the provider")
    }

    func testAllCachedArticlesIgnoresPaging() {
        cache.save(.samples(23))

        XCTAssertEqual(manager.allCachedArticles().count, 23)
        XCTAssertTrue(ArticlesManager(provider: provider, cache: MockArticlesCache(), logger: .silent).allCachedArticles().isEmpty)
    }

    // MARK: - Widget

    func testFreshArticlesArePublishedToTheWidget() async {
        provider.feed = .success([.sample(title: "Fresh")])

        _ = await manager.loadArticles()

        XCTAssertEqual(widgetSync.latestUpdates.map { $0.map(\.title) }, [["Fresh"]])
    }

    func testCachedArticlesArePublishedToTheWidgetAndFailuresAreNot() async {
        cache.save([.sample(title: "Saved")])

        _ = manager.cachedArticles()
        provider.feed = .failure(.offline)
        _ = await manager.loadArticles()

        XCTAssertEqual(widgetSync.latestUpdates.count, 1, "Only the cache read publishes; the failed refresh adds nothing new")
        XCTAssertEqual(widgetSync.latestUpdates.first?.map(\.title), ["Saved"])
    }
}
