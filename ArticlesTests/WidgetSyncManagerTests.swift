@testable import Articles
import XCTest

final class WidgetSyncManagerTests: XCTestCase {
    private let suiteName = "WidgetSyncManagerTests"
    private var store: SharedArticleStore!
    private var defaults: UserDefaults!
    private var downloads: [URL] = []
    private var downloadCompletions: [(Data?) -> Void] = []
    private var reloadCount = 0
    private var manager: WidgetSyncManager!

    override func setUp() {
        super.setUp()
        store = .temporary()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        downloads = []
        downloadCompletions = []
        reloadCount = 0
        manager = makeManager()
    }

    override func tearDown() {
        store.clear()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeManager() -> WidgetSyncManager {
        WidgetSyncManager(
            store: store,
            defaults: defaults,
            imageDownloader: { [weak self] url, completion in
                self?.downloads.append(url)
                self?.downloadCompletions.append(completion)
            },
            reloadWidgets: { [weak self] in self?.reloadCount += 1 },
            publishDelay: 0.01,
            logger: .silent
        )
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
            defaults: defaults,
            imageDownloader: { _, _ in XCTFail("No downloads without a container") },
            reloadWidgets: { reloads += 1 },
            publishDelay: 0.01,
            logger: .silent
        )

        inert.updateLatestArticles([article(1)])
        settle()

        XCTAssertEqual(reloads, 0)
    }

    // MARK: - Last opened article

    func testLastOpenedComesFirstThenSavedThenLatest() {
        let opened = article(3)
        let result = WidgetSyncManager.widgetArticles(
            latest: [article(1), article(2), opened],
            saved: [article(2)],
            lastOpened: opened
        )

        XCTAssertEqual(result.map(\.title), ["Article 3", "Article 2", "Article 1"])
        XCTAssertEqual(result.map(\.isSaved), [false, true, false])
    }

    func testLastOpenedSavedArticleIsFlaggedAsSaved() {
        let opened = article(2)
        let result = WidgetSyncManager.widgetArticles(latest: [article(1)], saved: [opened], lastOpened: opened)

        XCTAssertEqual(result.map(\.title), ["Article 2", "Article 1"])
        XCTAssertEqual(result.first?.isSaved, true)
    }

    func testOpeningAnArticlePutsItFirstAndResetsTheBrowseIndex() {
        manager.updateLatestArticles([article(1), article(2), article(3)])
        settle()
        store.cycleToNextArticle()
        store.cycleToNextArticle()
        XCTAssertEqual(store.currentIndex(), 2)

        manager.updateLastOpenedArticle(article(3))
        settle()

        XCTAssertEqual(store.loadArticles().map(\.title), ["Article 3", "Article 1", "Article 2"])
        XCTAssertEqual(store.currentArticle()?.article.title, "Article 3")
        XCTAssertEqual(store.currentIndex(), 0)
    }

    func testRefreshingTheListKeepsTheBrowseIndex() {
        manager.updateLatestArticles([article(1), article(2), article(3)])
        settle()
        store.cycleToNextArticle()

        manager.updateLatestArticles([article(1), article(2), article(3), article(4)])
        settle()

        XCTAssertEqual(store.currentIndex(), 1, "Only opening an article moves the widget; a refresh must not")
    }

    func testOpeningTheSameArticleAgainDoesNotRepublish() {
        manager.updateLatestArticles([article(1)])
        manager.updateLastOpenedArticle(article(1))
        settle()
        XCTAssertEqual(reloadCount, 1)

        manager.updateLastOpenedArticle(article(1))
        settle()

        XCTAssertEqual(reloadCount, 1)
    }

    func testLastOpenedArticleSurvivesARelaunch() {
        manager.updateLastOpenedArticle(article(7))
        settle()

        // A new manager, as after the app was killed and launched again.
        downloads = []
        reloadCount = 0
        let relaunched = makeManager()
        relaunched.updateLatestArticles([article(1), article(2)])
        settle()

        XCTAssertEqual(store.loadArticles().map(\.title), ["Article 7", "Article 1", "Article 2"])
    }

    func testLastOpenedArticleIsAvailableForDeepLinksAfterARelaunch() {
        XCTAssertNil(manager.lastOpenedArticle)
        manager.updateLastOpenedArticle(article(7))

        XCTAssertEqual(manager.lastOpenedArticle, article(7))
        XCTAssertEqual(makeManager().lastOpenedArticle, article(7), "A widget tap after a relaunch can still find it")
    }

    // MARK: - Coalescing launch-time updates

    func testBurstOfUpdatesPublishesOnceWithTheCompleteList() {
        manager.updateSavedArticles([article(2)])
        manager.updateLatestArticles([article(1), article(2), article(3)])
        settle()

        XCTAssertEqual(reloadCount, 1, "Saved and latest arriving together must produce one publish")
        XCTAssertEqual(store.loadArticles().map(\.title), ["Article 2", "Article 1", "Article 3"])
        XCTAssertEqual(downloads.count, 3)
    }

    func testRelaunchDoesNotPruneImagesOrResetTheIndex() {
        manager.updateLatestArticles([article(1), article(2)])
        settle()
        downloadCompletions.forEach { $0(Data("jpeg".utf8)) }
        settle()
        store.cycleToNextArticle()
        XCTAssertTrue(store.hasImage(for: article(2).identifier))

        // On launch the favourites manager reports first, then the articles manager.
        let relaunched = makeManager()
        downloads = []
        relaunched.updateSavedArticles([article(1)])
        relaunched.updateLatestArticles([article(1), article(2)])
        settle()

        XCTAssertTrue(store.hasImage(for: article(1).identifier))
        XCTAssertTrue(store.hasImage(for: article(2).identifier), "A partial list must not delete images of articles still listed")
        XCTAssertTrue(downloads.isEmpty, "Nothing is downloaded again")
        XCTAssertEqual(store.currentIndex(), 1)
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
