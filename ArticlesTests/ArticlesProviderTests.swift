@testable import Articles
import XCTest

final class ArticlesProviderTests: XCTestCase {
    private var client: MockNetworkClient!
    private var provider: ArticlesProvider!

    override func setUp() {
        super.setUp()
        client = MockNetworkClient()
        provider = ArticlesProvider(client: client, logger: .silent)
    }

    func testReturnsDecodedArticles() async throws {
        client.result = .success(Data(#"{"articles":[{"title":"One"},{"title":"Two"}]}"#.utf8))

        let articles = try await provider.fetchArticles()

        XCTAssertEqual(articles.map(\.title), ["One", "Two"])
    }

    func testDropsArticlesWithNothingToShow() async throws {
        client.result = .success(Data(#"{"articles":[{"author":"Nobody"},{"description":"Kept"}]}"#.utf8))

        let articles = try await provider.fetchArticles()

        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles.first?.description, "Kept")
    }

    func testInvalidJSONThrowsInvalidResponse() async {
        client.result = .success(Data("<html>Service unavailable</html>".utf8))

        do {
            _ = try await provider.fetchArticles()
            XCTFail("Expected invalidResponse")
        } catch {
            XCTAssertEqual(error as? NetworkError, .invalidResponse)
        }
    }

    func testNetworkErrorIsPropagated() async {
        client.result = .failure(.offline)

        do {
            _ = try await provider.fetchArticles()
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
