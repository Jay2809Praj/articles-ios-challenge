@testable import Articles
import XCTest

final class ArticlesProviderTests: XCTestCase {
    private var client: MockNetworkClient!
    private var sleeps: [TimeInterval] = []
    private var provider: ArticlesProvider!

    override func setUp() {
        super.setUp()
        client = MockNetworkClient()
        sleeps = []
        provider = ArticlesProvider(
            client: client,
            simulatedLatency: 0.42,
            sleep: { [weak self] seconds in self?.sleeps.append(seconds) },
            logger: .silent
        )
    }

    private func feed(count: Int) -> Data {
        let items = (1...count).map { #"{"title":"Article \#($0)"}"# }.joined(separator: ",")
        return Data(#"{"articles":[\#(items)]}"#.utf8)
    }

    // MARK: - Paging

    func testFirstPageDownloadsTheFeedAndReportsMore() async throws {
        client.result = .success(feed(count: 25))

        let page = try await provider.fetchArticles(page: 1, pageSize: 10)

        XCTAssertEqual(page.page, 1)
        XCTAssertEqual(page.articles.map(\.title), (1...10).map { "Article \($0)" })
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(client.requestCount, 1)
        XCTAssertTrue(sleeps.isEmpty, "A real download needs no simulated latency")
    }

    func testLaterPagesComeFromTheSnapshotAfterSimulatedLatency() async throws {
        client.result = .success(feed(count: 25))
        _ = try await provider.fetchArticles(page: 1, pageSize: 10)

        let page2 = try await provider.fetchArticles(page: 2, pageSize: 10)
        let page3 = try await provider.fetchArticles(page: 3, pageSize: 10)

        XCTAssertEqual(page2.articles.map(\.title), (11...20).map { "Article \($0)" })
        XCTAssertTrue(page2.hasMore)
        XCTAssertEqual(page3.articles.map(\.title), (21...25).map { "Article \($0)" })
        XCTAssertFalse(page3.hasMore)
        XCTAssertEqual(client.requestCount, 1, "Pages after the first are cut from the snapshot, not downloaded again")
        XCTAssertEqual(sleeps, [0.42, 0.42])
    }

    func testPageOneAlwaysRefreshesTheSnapshot() async throws {
        client.result = .success(feed(count: 12))
        _ = try await provider.fetchArticles(page: 1, pageSize: 10)

        client.result = .success(feed(count: 3))
        let refreshed = try await provider.fetchArticles(page: 1, pageSize: 10)
        let page2 = try await provider.fetchArticles(page: 2, pageSize: 10)

        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(refreshed.articles.count, 3)
        XCTAssertFalse(refreshed.hasMore)
        XCTAssertTrue(page2.articles.isEmpty)
        XCTAssertFalse(page2.hasMore)
    }

    func testLaterPageWithoutSnapshotDownloadsFirst() async throws {
        client.result = .success(feed(count: 15))

        let page2 = try await provider.fetchArticles(page: 2, pageSize: 10)

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(page2.articles.map(\.title), (11...15).map { "Article \($0)" })
        XCTAssertFalse(page2.hasMore)
    }

    func testExactMultipleOfPageSizeHasNoEmptyTrailingPage() async throws {
        client.result = .success(feed(count: 20))

        let page2 = try await provider.fetchArticles(page: 2, pageSize: 10)

        XCTAssertEqual(page2.articles.count, 10)
        XCTAssertFalse(page2.hasMore)
    }

    func testInvalidPageNumbersAreEmpty() async throws {
        client.result = .success(feed(count: 5))

        let zero = try await provider.fetchArticles(page: 0, pageSize: 10)
        let negative = try await provider.fetchArticles(page: -1, pageSize: 10)

        XCTAssertTrue(zero.articles.isEmpty)
        XCTAssertFalse(zero.hasMore)
        XCTAssertTrue(negative.articles.isEmpty)
        XCTAssertEqual(client.requestCount, 0)
    }

    func testEmptyFeedIsAnEmptyLastPage() async throws {
        client.result = .success(Data(#"{"articles":[]}"#.utf8))

        let page = try await provider.fetchArticles(page: 1, pageSize: 10)

        XCTAssertTrue(page.articles.isEmpty)
        XCTAssertFalse(page.hasMore)
    }

    // MARK: - Decoding and errors

    func testDropsArticlesWithNothingToShow() async throws {
        client.result = .success(Data(#"{"articles":[{"author":"Nobody"},{"description":"Kept"}]}"#.utf8))

        let page = try await provider.fetchArticles(page: 1, pageSize: 10)

        XCTAssertEqual(page.articles.count, 1)
        XCTAssertEqual(page.articles.first?.description, "Kept")
    }

    func testInvalidJSONThrowsInvalidResponse() async {
        client.result = .success(Data("<html>Service unavailable</html>".utf8))

        do {
            _ = try await provider.fetchArticles(page: 1, pageSize: 10)
            XCTFail("Expected invalidResponse")
        } catch {
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    func testNetworkErrorIsPropagated() async {
        client.result = .failure(.offline)

        do {
            _ = try await provider.fetchArticles(page: 1, pageSize: 10)
            XCTFail("Expected offline")
        } catch {
            XCTAssertEqual(error as? NetworkError, .offline)
        }
    }

    func testArticlesEndpointIsSecure() {
        XCTAssertEqual(Endpoint.articles.url.scheme, "https")
        XCTAssertEqual(Endpoint.articles.url.host, "mocki.io")
    }
}
