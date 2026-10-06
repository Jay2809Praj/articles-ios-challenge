@testable import Articles
import XCTest

/// The feed deliberately contains broken data; none of it may crash parsing.
final class ArticleDecodingTests: XCTestCase {
    private func decode(_ json: String) throws -> ArticlesResponse {
        try JSONDecoder().decode(ArticlesResponse.self, from: Data(json.utf8))
    }

    func testDecodesCompleteArticle() throws {
        let response = try decode("""
        {"status":"ok","totalResults":1,"articles":[{
            "source":{"id":"newsweek","name":"Newsweek"},
            "author":"Jane Doe","title":"A title","description":"A description",
            "url":"https://example.com/a","urlToImage":"https://example.com/a.jpg",
            "publishedAt":"2025-03-07T10:00:01Z","content":"Body"}]}
        """)

        let article = try XCTUnwrap(response.articles.first)
        XCTAssertEqual(article.source?.name, "Newsweek")
        XCTAssertEqual(article.author, "Jane Doe")
        XCTAssertEqual(article.title, "A title")
        XCTAssertEqual(article.urlToImage, "https://example.com/a.jpg")
    }

    func testMissingAndNullFieldsBecomeNil() throws {
        let response = try decode("""
        {"articles":[{"source":{"id":null,"name":"Thefly.com"},"author":null,
            "url":"https://example.com/a","publishedAt":"2025-03-07T09:44:14Z","content":"Body"}]}
        """)

        let article = try XCTUnwrap(response.articles.first)
        XCTAssertNil(article.author)
        XCTAssertNil(article.title)
        XCTAssertNil(article.description)
        XCTAssertNil(article.urlToImage)
        XCTAssertNil(article.source?.id)
    }

    func testEmptyAndBlankStringsBecomeNil() throws {
        let response = try decode("""
        {"articles":[{"title":"  ","description":"","urlToImage":"","content":"Body"}]}
        """)

        let article = try XCTUnwrap(response.articles.first)
        XCTAssertNil(article.title)
        XCTAssertNil(article.description)
        XCTAssertNil(article.urlToImage)
    }

    func testWrongTypesDoNotFailTheArticle() throws {
        let response = try decode("""
        {"status":42,"totalResults":"many","articles":[
            {"title":123,"author":{"name":"x"},"source":"not an object","content":"Body"}]}
        """)

        let article = try XCTUnwrap(response.articles.first)
        XCTAssertNil(article.title)
        XCTAssertNil(article.author)
        XCTAssertNil(article.source)
        XCTAssertEqual(article.content, "Body")
    }

    func testBrokenElementsAreSkipped() throws {
        let response = try decode("""
        {"articles":[null, 7, "text", [1,2], {"title":"Kept"}, {"title":"Also kept"}]}
        """)

        XCTAssertEqual(response.articles.compactMap(\.title), ["Kept", "Also kept"])
    }

    func testMissingArticlesKeyIsInvalid() {
        XCTAssertThrowsError(try decode(#"{"status":"ok"}"#))
    }

    func testMalformedJSONIsInvalid() {
        XCTAssertThrowsError(try decode(#"{"articles":[{"title":"Unterminated"#))
    }

    func testCachedArticlesRoundTrip() throws {
        let cached = CachedArticles(articles: [.sample(), .sample(title: nil, author: nil)], savedAt: Date())
        let data = try JSONEncoder().encode(cached)
        let restored = try JSONDecoder().decode(CachedArticles.self, from: data)

        XCTAssertEqual(restored.articles, cached.articles)
    }
}
