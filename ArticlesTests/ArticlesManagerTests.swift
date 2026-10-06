@testable import Articles
import XCTest

/// The offline behaviour the challenge tests explicitly.
final class ArticlesManagerTests: XCTestCase {
    private var provider: MockArticlesProvider!
    private var cache: MockArticlesCache!
    private var manager: ArticlesManager!

    override func setUp() {
        super.setUp()
        provider = MockArticlesProvider()
        cache = MockArticlesCache()
        manager = ArticlesManager(provider: provider, cache: cache, logger: .silent)
    }

    func testSuccessReturnsNetworkArticlesAndCachesThem() async {
        provider.result = .success([.sample(title: "Fresh")])

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.map(\.title), ["Fresh"])
        XCTAssertEqual(result.origin, .network)
        XCTAssertNil(result.error)
        XCTAssertEqual(cache.stored?.articles.map(\.title), ["Fresh"])
    }

    func testFailureFallsBackToCachedArticles() async {
        cache.save([.sample(title: "Saved")])
        provider.result = .failure(.offline)

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.map(\.title), ["Saved"])
        XCTAssertTrue(result.isStale)
        XCTAssertEqual(result.error, .offline)
    }

    func testInvalidResponseAlsoFallsBackToCache() async {
        cache.save([.sample(title: "Saved")])
        provider.result = .failure(.invalidResponse)

        let result = await manager.loadArticles()

        XCTAssertEqual(result.articles.count, 1)
        XCTAssertEqual(result.error, .invalidResponse)
    }

    func testFailureWithoutCacheReturnsErrorAndNoArticles() async {
        provider.result = .failure(.timedOut)

        let result = await manager.loadArticles()

        XCTAssertTrue(result.articles.isEmpty)
        XCTAssertEqual(result.error, .timedOut)
    }

    func testEmptyResponseDoesNotOverwriteCache() async {
        cache.save([.sample(title: "Saved")])
        provider.result = .success([])

        _ = await manager.loadArticles()

        XCTAssertEqual(cache.stored?.articles.map(\.title), ["Saved"])
    }

    func testCachedArticlesAreAvailableSynchronously() {
        XCTAssertNil(manager.cachedArticles())

        cache.save([.sample()])

        XCTAssertEqual(manager.cachedArticles()?.articles.count, 1)
        XCTAssertEqual(manager.cachedArticles()?.isStale, true)
    }
}
