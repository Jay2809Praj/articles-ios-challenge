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

    // MARK: - Widget Store

    func testSharedArticleStoreSavesAndLoadsArticles() {
        let store = SharedArticleStore.temporary()
        defer { store.clear() }
        let articles = [
            WidgetArticleData(id: "a", title: "First", sourceName: "Source 1", dateString: "Today", webURL: "https://1.com", isSaved: true),
            WidgetArticleData(id: "b", title: "Second", sourceName: "Source 2", dateString: "Yesterday", webURL: "https://2.com")
        ]

        XCTAssertTrue(store.isAvailable)
        XCTAssertTrue(store.loadArticles().isEmpty)

        store.saveArticles(articles)

        XCTAssertEqual(store.loadArticles(), articles)
        XCTAssertEqual(store.currentArticle()?.article.id, "a")
        XCTAssertEqual(store.currentArticle()?.total, 2)
    }

    func testSharedArticleStoreWithoutContainerIsInert() {
        let store = SharedArticleStore(containerURL: nil)

        XCTAssertFalse(store.isAvailable)
        store.saveArticles([WidgetArticleData(id: "a", title: "A")])
        store.saveImageData(Data([1, 2, 3]), for: "a")

        XCTAssertTrue(store.loadArticles().isEmpty)
        XCTAssertNil(store.currentArticle())
        XCTAssertNil(store.loadImageData(for: "a"))
    }

    func testSharedArticleStoreCyclesAndWrapsAround() {
        let store = SharedArticleStore.temporary()
        defer { store.clear() }
        store.saveArticles(["a", "b", "c"].map { WidgetArticleData(id: $0, title: $0) })

        XCTAssertEqual(store.currentIndex(), 0)
        store.cycleToNextArticle()
        XCTAssertEqual(store.currentIndex(), 1)
        store.cycleToPreviousArticle()
        XCTAssertEqual(store.currentIndex(), 0)
        store.cycleToPreviousArticle()
        XCTAssertEqual(store.currentIndex(), 2, "Previous from the first article wraps to the last")
        store.cycleToNextArticle()
        XCTAssertEqual(store.currentIndex(), 0, "Next from the last article wraps to the first")
    }

    func testSharedArticleStoreResetsIndexWhenListShrinks() {
        let store = SharedArticleStore.temporary()
        defer { store.clear() }
        store.saveArticles(["a", "b", "c"].map { WidgetArticleData(id: $0, title: $0) })
        store.cycleToNextArticle()
        store.cycleToNextArticle()
        XCTAssertEqual(store.currentIndex(), 2)

        store.saveArticles([WidgetArticleData(id: "a", title: "a")])

        XCTAssertEqual(store.currentArticle()?.index, 0)
        XCTAssertEqual(store.currentArticle()?.article.id, "a")
    }

    func testSharedArticleStoreStoresImagesPerArticleAndPrunesUnlistedOnes() {
        let store = SharedArticleStore.temporary()
        defer { store.clear() }
        store.saveArticles(["a", "b"].map { WidgetArticleData(id: $0, title: $0) })
        let imageA = Data("image-a".utf8)
        let imageB = Data("image-b".utf8)

        store.saveImageData(imageA, for: "a")
        store.saveImageData(imageB, for: "b")
        XCTAssertTrue(store.hasImage(for: "a"))
        XCTAssertEqual(store.loadImageData(for: "a"), imageA)
        XCTAssertEqual(store.loadImageData(for: "b"), imageB)

        // Article "b" drops out of the list, so its image goes with it.
        store.saveArticles([WidgetArticleData(id: "a", title: "a")])

        XCTAssertEqual(store.loadImageData(for: "a"), imageA)
        XCTAssertFalse(store.hasImage(for: "b"))
        XCTAssertNil(store.loadImageData(for: "b"))
    }

    func testSharedArticleStoreClearRemovesEverything() {
        let store = SharedArticleStore.temporary()
        store.saveArticles([WidgetArticleData(id: "a", title: "a")])
        store.saveImageData(Data([1]), for: "a")
        store.cycleToNextArticle()

        store.clear()

        XCTAssertTrue(store.loadArticles().isEmpty)
        XCTAssertNil(store.loadImageData(for: "a"))
        XCTAssertEqual(store.currentIndex(), 0)
    }

    // MARK: - Deep Linking

    func testWidgetDeepLinkCarriesTheArticleIdentifier() {
        let identifier = "https://example.com/article?id=123&x=1|2025-03-07T11:00:59Z|Title"
        var components = URLComponents()
        components.scheme = "articles"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "id", value: identifier)]

        let deepLink = components.url
        XCTAssertNotNil(deepLink)
        XCTAssertEqual(deepLink?.scheme, "articles")
        XCTAssertEqual(deepLink?.host, "open")

        let parsed = URLComponents(url: deepLink!, resolvingAgainstBaseURL: false)
        XCTAssertEqual(parsed?.queryItems?.first(where: { $0.name == "id" })?.value, identifier)
    }
}
