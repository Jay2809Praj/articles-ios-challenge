@testable import Articles
import XCTest

final class WidgetSyncManagerTests: XCTestCase {
    private var store: SharedArticleStore!
    private var downloads: [URL] = []
    private var downloadCompletions: [(Data?) -> Void] = []
    private var reloadCount = 0
    private var manager: WidgetSyncManager!

    override func setUp() {
        super.setUp()
        store = .temporary()
        downloads = []
        downloadCompletions = []
        reloadCount = 0
        manager = WidgetSyncManager(
            store: store,
            imageDownloader: { [weak self] url, completion in
                self?.downloads.append(url)
                self?.downloadCompletions.append(completion)
            },
            reloadWidgets: { [weak self] in self?.reloadCount += 1 },
            logger: .silent
        )
    }

    override func tearDown() {
        store.clear()
        super.tearDown()
    }

    /// Lets the manager's serial queue drain.
    private func settle() {
        let done = expectation(description: "sync settled")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 2)
    }

    private func article(_ index: Int, image: String? = "https://example.com/image.jpg") -> Article {
        Article(
            source: ArticleSource(id: nil, name: "Source \(index)"),
            title: "Article \(index)",
            url: "https://example.com/\(index)",
            urlToImage: image,
            publishedAt: "2025-03-07T11:00:59Z"
        )
    }

    // MARK: - List composition (pure)

    func testSavedArticlesComeFirstWithoutDuplicates() {
        let shared = article(1)
        let result = WidgetSyncManager.widgetArticles(
            latest: [shared, article(2), article(3)],
            saved: [article(9), shared]
        )

        XCTAssertEqual(result.map(\.title), ["Article 9", "Article 1", "Article 2", "Article 3"])
        XCTAssertEqual(result.map(\.isSaved), [true, true, false, false])
        XCTAssertEqual(result.first?.id, article(9).identifier)
        XCTAssertEqual(result.first?.sourceName, "Source 9")
        XCTAssertEqual(result.first?.webURL, "https://example.com/9")
        XCTAssertEqual(result.first?.dateString, "7 Mar,2025")
    }

    func testListIsCappedAtTenArticles() {
        let result = WidgetSyncManager.widgetArticles(latest: (1...25).map { article($0) }, saved: [])
        XCTAssertEqual(result.count, WidgetSyncManager.maxArticles)
        XCTAssertEqual(result.last?.title, "Article 10")
    }

    func testTitleFallsBackToDescriptionThenPlaceholder() {
        let noTitle = Article(description: "Only a description", url: "https://example.com/a", publishedAt: "2025-03-07T11:00:59Z")
        let nothing = Article(url: "https://example.com/b", publishedAt: "2025-03-07T11:00:59Z")

        let result = WidgetSyncManager.widgetArticles(latest: [noTitle, nothing], saved: [])

        XCTAssertEqual(result.map(\.title), ["Only a description", WidgetSyncManager.untitled])
    }

    // MARK: - Publishing

    func testUpdateLatestWritesStoreAndReloadsOnce() {
        manager.updateLatestArticles([article(1), article(2)])
        settle()

        XCTAssertEqual(store.loadArticles().map(\.title), ["Article 1", "Article 2"])
        XCTAssertEqual(reloadCount, 1, "One reload for the list; images have not arrived yet")
        XCTAssertEqual(downloads.count, 2)
    }

    func testSavedArticlesAreMergedIntoThePublishedList() {
        manager.updateLatestArticles([article(1), article(2)])
        manager.updateSavedArticles([article(2)])
        settle()

        let published = store.loadArticles()
        XCTAssertEqual(published.map(\.title), ["Article 2", "Article 1"])
        XCTAssertEqual(published.first?.isSaved, true)
    }

    func testImagesAreDownloadedOnceAndStoredPerArticle() {
        manager.updateLatestArticles([article(1)])
        settle()
        XCTAssertEqual(downloads.count, 1)

        downloadCompletions[0](Data("jpeg".utf8))
        settle()

        XCTAssertEqual(store.loadImageData(for: article(1).identifier), Data("jpeg".utf8))
        XCTAssertEqual(reloadCount, 2, "A second reload once the image is on disk")

        // Publishing the same article again must not fetch the image again.
        manager.updateLatestArticles([article(1)])
        settle()
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(reloadCount, 3)
    }

    func testInFlightDownloadIsNotRepeatedByASecondPublish() {
        manager.updateLatestArticles([article(1)])
        manager.updateSavedArticles([article(1)])
        settle()

        XCTAssertEqual(downloads.count, 1)
    }

    func testFailedDownloadDoesNotReload() {
        manager.updateLatestArticles([article(1)])
        settle()

        downloadCompletions[0](nil)
        settle()

        XCTAssertNil(store.loadImageData(for: article(1).identifier))
        XCTAssertEqual(reloadCount, 1)
    }

    func testArticlesWithoutImageURLAreNotDownloaded() {
        manager.updateLatestArticles([article(1, image: nil)])
        settle()

        XCTAssertTrue(downloads.isEmpty)
        XCTAssertEqual(store.loadArticles().count, 1)
    }

    func testUnavailableStoreIsLeftAlone() {
        var reloads = 0
        let inert = WidgetSyncManager(
            store: SharedArticleStore(containerURL: nil),
            imageDownloader: { _, _ in XCTFail("No downloads without a container") },
            reloadWidgets: { reloads += 1 },
            logger: .silent
        )

        inert.updateLatestArticles([article(1)])
        settle()

        XCTAssertEqual(reloads, 0)
    }

    // MARK: - Image downsampling

    func testDownsampledJPEGShrinksLargeImages() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2000, height: 1500))
        let original = renderer.pngData { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2000, height: 1500))
        }

        let data = WidgetSyncManager.downsampledJPEG(from: original, maxPixelSize: 800)

        XCTAssertNotNil(data)
        let image = data.flatMap(UIImage.init(data:))
        XCTAssertEqual(image?.size.width, 800)
        XCTAssertEqual(image?.size.height, 600)
        XCTAssertLessThan(data!.count, original.count)
    }

    func testDownsampledJPEGRejectsGarbage() {
        XCTAssertNil(WidgetSyncManager.downsampledJPEG(from: Data("not an image".utf8)))
    }
}
