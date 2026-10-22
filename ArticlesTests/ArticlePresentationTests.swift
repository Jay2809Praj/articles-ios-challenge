@testable import Articles
import XCTest

final class ArticlePresentationTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2025-03-07T21:00:59Z")!

    // MARK: - ArticleDisplay

    func testCompleteArticle() {
        let display = ArticleDisplay(article: .sample(), now: now)

        XCTAssertEqual(display.title, "Title")
        XCTAssertEqual(display.listDate, "7 Mar,2025")
        XCTAssertEqual(display.detailMeta, "10h ago  ·  Author")
        XCTAssertEqual(display.webURL?.absoluteString, "https://example.com/article")
        XCTAssertEqual(display.imageURL?.absoluteString, "https://example.com/image.jpg")
    }

    func testMissingTitleFallsBackToDescriptionThenPlaceholder() {
        XCTAssertEqual(ArticleDisplay(article: .sample(title: nil)).title, "Description")
        XCTAssertEqual(ArticleDisplay(article: .sample(title: nil, description: nil)).title, ArticleDisplay.untitled)
    }

    func testNullAuthorFallsBackToSource() {
        let display = ArticleDisplay(article: .sample(author: nil), now: now)

        XCTAssertEqual(display.detailMeta, "10h ago  ·  Source")
    }

    func testMissingDateAndBylineHideTheMetaRow() {
        let display = ArticleDisplay(article: Article(title: "Only a title"))

        XCTAssertNil(display.listDate)
        XCTAssertNil(display.detailMeta)
        XCTAssertFalse(display.hasDate)
        XCTAssertEqual(display.body, ArticleDisplay.noPreview)
    }

    func testBodyStripsTruncationMarker() {
        let article = Article(title: "T", content: "Opening words… [+3029 Lorem ipsum dolor sit amet.")

        XCTAssertEqual(ArticleDisplay(article: article).body, "Opening words… Lorem ipsum dolor sit amet.")
    }

    func testBodyDoesNotRepeatDescriptionThatOpensTheContent() {
        let opening = "Cardano Founder Charles Hoskinson has hinted at the possibility"
        let article = Article(title: "T", description: opening + " of more.", content: opening + "… and the rest.")

        XCTAssertEqual(ArticleDisplay(article: article).body, opening + "… and the rest.")
    }

    // MARK: - Links

    func testValidLinks() {
        XCTAssertNotNil(ArticleLinkValidator.webURL(from: "https://example.com/path?q=1"))
        XCTAssertNotNil(ArticleLinkValidator.webURL(from: "http://grist.org/transportation/"))
    }

    func testInvalidLinks() {
        let invalid = [nil, "", "not a url", "example.com/no-scheme", "ftp://example.com/file",
                       "javascript:alert(1)", "https://", "https://localhost", "https:// spaced.com"]

        for link in invalid {
            XCTAssertNil(ArticleLinkValidator.webURL(from: link), "\(link ?? "nil") should be rejected")
        }
    }

    // MARK: - Dates

    func testRelativeDates() {
        func ago(_ seconds: TimeInterval) -> String {
            ArticleDateFormatter.shortRelativeString(for: now.addingTimeInterval(-seconds), relativeTo: now)
        }

        XCTAssertEqual(ago(10), "Just now")
        XCTAssertEqual(ago(5 * 60), "5m ago")
        XCTAssertEqual(ago(10 * 3_600), "10h ago")
        XCTAssertEqual(ago(3 * 86_400), "3d ago")
        XCTAssertEqual(ago(400 * 86_400), "1y ago")
    }

    func testUnparseableDateIsNil() {
        XCTAssertNil(ArticleDateFormatter.displayString(from: "yesterday"))
        XCTAssertNil(ArticleDateFormatter.displayString(from: nil))
    }

    // MARK: - Search

    func testSearchMatchesAcrossFieldsIgnoringCase() {
        let articles = [
            Article.sample(title: "Tesla shareholders", author: "RIA Team"),
            Article.sample(title: "Clean energy", author: "Alex"),
            Article.sample(title: nil, description: "Virtual power plant", author: nil)
        ]

        XCTAssertEqual(ArticleSearchFilter.filter(articles, matching: "tesla").count, 1)
        XCTAssertEqual(ArticleSearchFilter.filter(articles, matching: "ALEX energy").count, 1)
        XCTAssertEqual(ArticleSearchFilter.filter(articles, matching: "power").count, 1)
        XCTAssertEqual(ArticleSearchFilter.filter(articles, matching: "   ").count, 3)
        XCTAssertTrue(ArticleSearchFilter.filter(articles, matching: "zzqx").isEmpty)
    }

    // MARK: - Section Filter & Saved State

    func testSectionFilterEnumValues() {
        XCTAssertEqual(ArticleListSectionFilter.all.rawValue, 0)
        XCTAssertEqual(ArticleListSectionFilter.saved.rawValue, 1)
        XCTAssertEqual(ArticleListSectionFilter(rawValue: 0), .all)
        XCTAssertEqual(ArticleListSectionFilter(rawValue: 1), .saved)
    }

    func testContentStateViewEmptySavedState() {
        let state = ContentStateView(kind: .emptySaved)
        XCTAssertEqual(state.kind, .emptySaved)
    }

    func testSearchFiltersSavedSubset() {
        let savedArticles = [
            Article.sample(title: "Saved Swift Guide", url: "https://example.com/swift"),
            Article.sample(title: "Saved Kotlin Guide", url: "https://example.com/kotlin")
        ]

        let searchSwift = ArticleSearchFilter.filter(savedArticles, matching: "swift")
        XCTAssertEqual(searchSwift.count, 1)
        XCTAssertEqual(searchSwift.first?.title, "Saved Swift Guide")

        let searchNone = ArticleSearchFilter.filter(savedArticles, matching: "flutter")
        XCTAssertTrue(searchNone.isEmpty)
    }

    // MARK: - Simulated Infinite Scrolling (Pagination)

    func testPaginatorInitialPage() {
        let sampleArticles = (1...25).map { index in
            Article.sample(title: "Article \(index)", url: "https://example.com/\(index)")
        }

        let page1 = ArticlePaginator.paginate(sampleArticles, page: 1, pageSize: 10)
        XCTAssertEqual(page1.count, 10)
        XCTAssertEqual(page1.first?.title, "Article 1")
        XCTAssertEqual(page1.last?.title, "Article 10")
        XCTAssertTrue(ArticlePaginator.hasMorePages(totalCount: sampleArticles.count, page: 1, pageSize: 10))
    }

    func testPaginatorSecondAndFinalPages() {
        let sampleArticles = (1...25).map { index in
            Article.sample(title: "Article \(index)", url: "https://example.com/\(index)")
        }

        let page2 = ArticlePaginator.paginate(sampleArticles, page: 2, pageSize: 10)
        XCTAssertEqual(page2.count, 20)
        XCTAssertEqual(page2.last?.title, "Article 20")
        XCTAssertTrue(ArticlePaginator.hasMorePages(totalCount: sampleArticles.count, page: 2, pageSize: 10))

        let page3 = ArticlePaginator.paginate(sampleArticles, page: 3, pageSize: 10)
        XCTAssertEqual(page3.count, 25)
        XCTAssertEqual(page3.last?.title, "Article 25")
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: sampleArticles.count, page: 3, pageSize: 10))
    }

    func testPaginatorBoundaryConditions() {
        let empty: [Article] = []
        XCTAssertTrue(ArticlePaginator.paginate(empty, page: 1, pageSize: 10).isEmpty)
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: 0, page: 1, pageSize: 10))

        // Less than 1 page
        let fourArticles = (1...4).map { Article.sample(title: "Article \($0)", url: "https://example.com/\($0)") }
        let pagedFour = ArticlePaginator.paginate(fourArticles, page: 1, pageSize: 10)
        XCTAssertEqual(pagedFour.count, 4)
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: 4, page: 1, pageSize: 10))

        // Exact page size boundary (20 items with pageSize = 10)
        let twentyArticles = (1...20).map { Article.sample(title: "Article \($0)", url: "https://example.com/\($0)") }
        XCTAssertTrue(ArticlePaginator.hasMorePages(totalCount: 20, page: 1, pageSize: 10))
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: 20, page: 2, pageSize: 10))

        // Invalid page numbers
        XCTAssertTrue(ArticlePaginator.paginate(twentyArticles, page: 0, pageSize: 10).isEmpty)
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: 20, page: 0, pageSize: 10))
        XCTAssertFalse(ArticlePaginator.hasMorePages(totalCount: 20, page: -1, pageSize: 10))
    }
}
