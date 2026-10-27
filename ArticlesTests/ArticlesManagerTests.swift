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

    // MARK: - Overlapping requests (Part 1 review)

    func testNextPageThatArrivesAfterARefreshIsDropped() async {
        let gated = GatedArticlesProvider()
        let manager = ArticlesManager(provider: gated, cache: cache, pageSize: 10, logger: .silent)
        let oldFeed = Array([Article].samples(20))
        let newFeed = (1...10).map { Article.sample(title: "New \($0)", url: "https://example.com/new/\($0)") }

        let first = Task { await manager.loadArticles() }
        await gated.waitForRequests(1)
        gated.answer(page: 1, with: Array(oldFeed.prefix(10)), hasMore: true)
        _ = await first.value

        // Page 2 is on its way when the user pulls to refresh.
        let nextPage = Task { await manager.loadNextPage() }
        await gated.waitForRequests(2)
        let refresh = Task { await manager.loadArticles() }
        await gated.waitForRequests(3)
        gated.answer(page: 1, with: newFeed, hasMore: true)
        let refreshed = await refresh.value
        gated.answer(page: 2, with: Array(oldFeed.suffix(10)), hasMore: false)
        let late = await nextPage.value

        XCTAssertEqual(refreshed.articles.map(\.title), newFeed.map(\.title))
        XCTAssertEqual(late.articles.map(\.title), newFeed.map(\.title), "The old page 2 is not glued onto the new list")
        XCTAssertTrue(late.hasMore)
        XCTAssertEqual(cache.stored?.articles.map(\.title), newFeed.map(\.title))

        // Paging carries on from the new list's page 2.
        let following = Task { await manager.loadNextPage() }
        await gated.waitForRequests(4)
        XCTAssertEqual(gated.requestedPages, [1, 2, 1, 2])
        gated.answerNext(with: [.sample(title: "New 11", url: "https://example.com/new/11")], hasMore: false)
        let extended = await following.value
        XCTAssertEqual(extended.articles.count, 11)
        XCTAssertEqual(extended.articles.last?.title, "New 11")
    }

    func testCallsWhilePageOneIsLoadingShareOneRequest() async {
        let gated = GatedArticlesProvider()
        let manager = ArticlesManager(provider: gated, cache: cache, pageSize: 10, logger: .silent)

        let launchLoad = Task { await manager.loadArticles() }
        await gated.waitForRequests(1)
        // A widget deep link and a reconnect ask again before page 1 is back.
        let deepLinkLoad = Task { await manager.loadArticles() }
        let reconnectLoad = Task { await manager.loadArticles() }
        try? await Task.sleep(nanoseconds: 50_000_000)
        // Answer as many page-1 requests as were made, so a regression fails
        // the assertion below instead of hanging.
        for _ in 0..<3 {
            gated.answer(page: 1, with: [.sample(title: "Fresh")], hasMore: false)
        }

        let results = await [launchLoad.value, deepLinkLoad.value, reconnectLoad.value]

        XCTAssertEqual(gated.requestedPages, [1], "One request answers all three callers")
        XCTAssertEqual(results.map { $0.articles.map(\.title) }, Array(repeating: ["Fresh"], count: 3))

        // Once it has finished, a new call asks the provider again.
        let later = Task { await manager.loadArticles() }
        await gated.waitForRequests(2)
        gated.answer(page: 1, with: [.sample(title: "Later")], hasMore: false)
        let laterResult = await later.value
        XCTAssertEqual(laterResult.articles.map(\.title), ["Later"])
    }

    func testRefreshAfterOfflinePagingStartsANewList() async {
        cache.save(.samples(25))
        provider.feed = .failure(.offline)
        _ = await manager.loadArticles()          // cache, page 1 of 3

        let page2 = await manager.loadNextPage()
        XCTAssertEqual(page2.articles.count, 20)
        provider.feed = .success([.sample(title: "Back")])
        let refreshed = await manager.loadArticles()
        let afterRefresh = await manager.loadNextPage()

        XCTAssertEqual(refreshed.articles.map(\.title), ["Back"])
        XCTAssertEqual(afterRefresh.articles.map(\.title), ["Back"], "Nothing from the old cached list comes back")
        XCTAssertEqual(afterRefresh.origin, .network)
    }

    // MARK: - Reconnect rule

    func testOnlyStaleFailedOrEmptyListsAreReloadedWhenOnline() {
        let fresh = ArticlesLoadResult(articles: [.sample()], origin: .network, error: nil, hasMore: true)
        let cached = ArticlesLoadResult(articles: [.sample()], origin: .cache(savedAt: Date()), error: nil, hasMore: false)
        let failed = ArticlesLoadResult(articles: [.sample()], origin: .cache(savedAt: Date()), error: .offline, hasMore: false)
        let empty = ArticlesLoadResult(articles: [], origin: .network, error: nil, hasMore: false)

        XCTAssertFalse(fresh.needsRefreshWhenOnline, "Fresh pages are kept, scroll position and all")
        XCTAssertTrue(cached.needsRefreshWhenOnline)
        XCTAssertTrue(failed.needsRefreshWhenOnline)
        XCTAssertTrue(empty.needsRefreshWhenOnline)
    }
}
