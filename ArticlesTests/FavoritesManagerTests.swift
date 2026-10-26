@testable import Articles
import XCTest

final class FavoritesManagerTests: XCTestCase {
    private let suiteName = "FavoritesManagerTests"
    private var defaults: UserDefaults!
    private var imageStore: MockSavedImageStore!
    /// Every download the manager asked for, with the completion to answer it.
    private var downloads: [(url: URL, completion: (Data?) -> Void)] = []
    private let downloadsLock = NSLock()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        imageStore = MockSavedImageStore()
        downloads = []
        makeManager().clearAll()
    }

    override func tearDown() {
        makeManager().clearAll()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// A manager whose downloads are recorded and answered by the test.
    /// `answer` is called synchronously for each download when given.
    private func makeManager(
        limitBytes: Int64 = AppConstants.SavedArticles.maxStorageBytes,
        widgetSync: WidgetSyncManagerProtocol? = nil,
        answer: ((URL) -> Data?)? = nil
    ) -> FavoritesManager {
        FavoritesManager(
            defaults: defaults,
            storageName: suiteName,
            storageLimitBytes: limitBytes,
            imageStore: imageStore,
            imageDownloader: { [weak self] url, completion in
                guard let self else { return }
                if let answer {
                    completion(answer(url))
                } else {
                    self.downloadsLock.withLock { self.downloads.append((url, completion)) }
                }
            },
            widgetSync: widgetSync,
            logger: .silent
        )
    }

    private func finishDownload(_ index: Int, with data: Data?) {
        let completion = downloadsLock.withLock { downloads[index].completion }
        completion(data)
    }

    // MARK: - Saving and removing

    func testToggleAddsAndRemoves() {
        let manager = makeManager()
        let article = Article.sample()

        XCTAssertFalse(manager.isFavorite(article))
        XCTAssertTrue(manager.toggleFavorite(article))
        XCTAssertTrue(manager.isFavorite(article))
        XCTAssertFalse(manager.toggleFavorite(article))
        XCTAssertFalse(manager.isFavorite(article))
    }

    func testFavoritesPersistAcrossInstances() {
        let article = Article.sample()
        let manager1 = makeManager()
        manager1.toggleFavorite(article)

        let manager2 = makeManager()
        XCTAssertTrue(manager2.isFavorite(article))
    }

    func testSaveStoresFullArticleModel() {
        let manager = makeManager()
        let article = Article.sample(title: "Detailed Article", description: "Rich Description", url: "https://example.com/1")

        manager.save(article)

        XCTAssertTrue(manager.isSaved(article))
        let savedList = manager.savedArticles()
        XCTAssertEqual(savedList.count, 1)
        XCTAssertEqual(savedList.first?.title, "Detailed Article")
        XCTAssertEqual(savedList.first?.description, "Rich Description")
    }

    func testSavedArticlesAreSortedMostRecentlySavedFirst() {
        let manager = makeManager()
        let first = Article.sample(title: "Article 1", url: "https://example.com/1")
        let second = Article.sample(title: "Article 2", url: "https://example.com/2")

        manager.save(first)
        manager.save(second)

        XCTAssertEqual(manager.savedArticles().map(\.title), ["Article 2", "Article 1"])
    }

    func testRapidTogglingMaintainsConsistentState() {
        let manager = makeManager()
        let article = Article.sample(title: "Rapid Toggle", url: "https://example.com/rapid")

        for i in 1...10 {
            let isSaved = manager.toggleSave(article)
            let expected = (i % 2 != 0)
            XCTAssertEqual(isSaved, expected, "Failed on toggle iteration \(i)")
            XCTAssertEqual(manager.isSaved(article), expected)
        }

        XCTAssertFalse(manager.isSaved(article))
        XCTAssertTrue(manager.savedArticles().isEmpty)
    }

    func testClearAllRemovesAllArticlesAndImages() {
        let manager = makeManager(answer: { _ in Data(count: 10) })
        manager.save(Article.sample(title: "A1", url: "https://example.com/1"))
        manager.save(Article.sample(title: "A2", url: "https://example.com/2"))
        XCTAssertEqual(manager.savedArticles().count, 2)
        XCTAssertEqual(imageStore.storedIDs.count, 2)
        let removeAllsBefore = imageStore.removeAllCount

        manager.clearAll()

        XCTAssertTrue(manager.savedArticles().isEmpty)
        XCTAssertEqual(manager.totalStorageBytes, 0)
        XCTAssertEqual(imageStore.removeAllCount, removeAllsBefore + 1)
        XCTAssertTrue(imageStore.storedIDs.isEmpty)
    }

    // MARK: - Images owned by the app

    func testSavingDownloadsTheImageIntoTheAppsStoreWithItsRealSize() {
        let manager = makeManager()
        let article = Article.sample(title: "With Image", url: "https://example.com/img")

        manager.save(article)
        XCTAssertEqual(downloads.count, 1)
        XCTAssertEqual(downloads.first?.url.absoluteString, "https://example.com/image.jpg")
        XCTAssertNil(manager.savedImageURL(for: article), "No file until the download finishes")
        let before = manager.totalStorageBytes

        finishDownload(0, with: Data(count: 4_321))

        XCTAssertEqual(imageStore.storedIDs, [article.identifier])
        XCTAssertNotNil(manager.savedImageURL(for: article))
        XCTAssertEqual(manager.totalStorageBytes, before + 4_321, "The budget counts the bytes written, not an estimate")
    }

    func testSavedImageURLIsOnlyExposedForSavedArticles() {
        let manager = makeManager(answer: { _ in Data(count: 10) })
        let saved = Article.sample(title: "Saved", url: "https://example.com/saved")
        let other = Article.sample(title: "Other", url: "https://example.com/other")

        manager.save(saved)

        XCTAssertNotNil(manager.savedImageURL(for: saved))
        XCTAssertNil(manager.savedImageURL(for: other))

        manager.remove(saved)
        XCTAssertNil(manager.savedImageURL(for: saved))
    }

    func testRemoveArticleDeletesItsImageFile() {
        let manager = makeManager(answer: { _ in Data(count: 10) })
        let article = Article.sample(title: "To Remove", url: "https://example.com/removable")
        manager.save(article)
        XCTAssertTrue(manager.isSaved(article))

        manager.remove(article)

        XCTAssertFalse(manager.isSaved(article))
        XCTAssertTrue(manager.savedArticles().isEmpty)
        XCTAssertEqual(imageStore.removed, [article.identifier])
        XCTAssertTrue(imageStore.storedIDs.isEmpty)
    }

    func testFailedDownloadLeavesTheArticleSavedWithoutAnImage() {
        let manager = makeManager()
        let article = Article.sample(title: "Offline Save", url: "https://example.com/offline")

        manager.save(article)
        finishDownload(0, with: nil)

        XCTAssertTrue(manager.isSaved(article))
        XCTAssertNil(manager.savedImageURL(for: article))
        XCTAssertTrue(imageStore.storedIDs.isEmpty)
    }

    func testImageArrivingAfterRemovalIsDiscarded() {
        let manager = makeManager()
        let article = Article.sample(title: "Gone", url: "https://example.com/gone")

        manager.save(article)
        manager.remove(article)
        finishDownload(0, with: Data(count: 100))

        XCTAssertTrue(imageStore.storedIDs.isEmpty)
        XCTAssertEqual(manager.totalStorageBytes, 0)
    }

    func testMissingImagesAreDownloadedAgainOnLaunch() {
        let article = Article.sample(title: "Interrupted", url: "https://example.com/interrupted")
        let first = makeManager()
        first.save(article)
        // The app was killed before the download finished: no file on disk.
        XCTAssertEqual(downloads.count, 1)

        let relaunched = makeManager()

        XCTAssertEqual(downloads.count, 2, "Launch retries the missing image")
        finishDownload(1, with: Data(count: 2_000))
        XCTAssertNotNil(relaunched.savedImageURL(for: article))
        XCTAssertEqual(relaunched.totalStorageBytes, SavedArticleRecord(article: article).articleByteSize + 2_000)
    }

    func testSizesAreReReadFromDiskOnLaunch() {
        let article = Article.sample(title: "Resized", url: "https://example.com/resized")
        let first = makeManager(answer: { _ in Data(count: 5_000) })
        first.save(article)
        XCTAssertEqual(first.totalStorageBytes, SavedArticleRecord(article: article).articleByteSize + 5_000)

        // The file changed behind the manager's back.
        imageStore.save(Data(count: 1_000), for: article.identifier)
        let relaunched = makeManager(answer: { _ in XCTFail("Nothing to download"); return nil })

        XCTAssertEqual(relaunched.totalStorageBytes, SavedArticleRecord(article: article).articleByteSize + 1_000)
    }

    func testSynchronousImageDownloaderDoesNotDeadlock() {
        let manager = makeManager(answer: { _ in Data(count: 45_000) })
        let article = Article.sample(title: "Sync Download", url: "https://example.com/syncdownload")

        for _ in 1...10 {
            manager.save(article)
            XCTAssertTrue(manager.isSaved(article))
            XCTAssertNotNil(manager.savedImageURL(for: article))
            manager.remove(article)
            XCTAssertFalse(manager.isSaved(article))
        }
    }

    func testConcurrentRapidTogglingNeverDeadlocks() {
        let manager = makeManager(answer: { _ in Data(count: 25_000) })
        let article = Article.sample(title: "Concurrent", url: "https://example.com/concurrent")

        let group = DispatchGroup()
        for _ in 0..<6 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<20 {
                    manager.toggleSave(article)
                    _ = manager.isSaved(article)
                    _ = manager.savedImageURL(for: article)
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "Concurrent toggles deadlocked!")
    }

    // MARK: - 50 MB budget

    func test50MBStorageLimitEvictsOldestArticleWhenExceeded() {
        // Each sample article encodes to ~270 bytes. Set limit to 600 bytes so 2 fit but 3 exceed.
        let manager = makeManager(limitBytes: 600)

        let article1 = Article.sample(title: "Article 1", url: "https://example.com/1")
        let article2 = Article.sample(title: "Article 2", url: "https://example.com/2")
        let article3 = Article.sample(title: "Article 3", url: "https://example.com/3")

        manager.save(article1)
        manager.save(article2)
        XCTAssertEqual(manager.savedArticles().count, 2)

        // Saving article 3 pushes total size past 600 bytes, so oldest (article 1) is evicted
        manager.save(article3)

        let remaining = manager.savedArticles()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertFalse(remaining.contains(where: { $0.title == "Article 1" }))
        XCTAssertTrue(remaining.contains(where: { $0.title == "Article 2" }))
        XCTAssertTrue(remaining.contains(where: { $0.title == "Article 3" }))
        XCTAssertEqual(imageStore.removed, [article1.identifier], "The evicted article's image file is deleted")
    }

    func testAsyncImageSizeUpdateReEnforcesStorageLimit() {
        // Budget: 1000 bytes. Two articles fit without images; their images push the total over.
        let manager = makeManager(limitBytes: 1000)
        let article1 = Article.sample(title: "Async Art 1", url: "https://example.com/async1")
        let article2 = Article.sample(title: "Async Art 2", url: "https://example.com/async2")

        manager.save(article1)
        manager.save(article2)
        XCTAssertEqual(manager.savedArticles().count, 2)
        XCTAssertTrue(manager.totalStorageBytes < 1000, "Without images, both fit within budget")

        finishDownload(0, with: Data(count: 600))
        finishDownload(1, with: Data(count: 500))

        XCTAssertTrue(manager.totalStorageBytes <= 1000,
                      "Total storage (\(manager.totalStorageBytes)) should not exceed the limit after the images arrived")
    }

    func testSingleArticleExceedingBudgetIsEvicted() {
        let manager = makeManager(limitBytes: 500)
        let article = Article.sample(title: "Oversized Article", url: "https://example.com/oversized")
        manager.save(article)
        XCTAssertEqual(manager.savedArticles().count, 1)

        finishDownload(0, with: Data(count: 50_000))

        XCTAssertTrue(manager.savedArticles().isEmpty, "Article whose total size exceeds the entire budget should be removed")
        XCTAssertEqual(manager.totalStorageBytes, 0)
        XCTAssertEqual(imageStore.removed, [article.identifier], "Oversized article's image is deleted")
        XCTAssertTrue(imageStore.storedIDs.isEmpty)
    }

    func testAsyncImageSizeUpdateEvictsOldestToMakeRoom() {
        let manager = makeManager(limitBytes: 800)
        let article1 = Article.sample(title: "Evict Art 1", url: "https://example.com/evict1")
        let article2 = Article.sample(title: "Evict Art 2", url: "https://example.com/evict2")
        let article3 = Article.sample(title: "Evict Art 3", url: "https://example.com/evict3")

        manager.save(article1)
        manager.save(article2)
        manager.save(article3)
        XCTAssertEqual(manager.savedArticles().count, 3)

        finishDownload(0, with: Data(count: 200))
        finishDownload(1, with: Data(count: 200))
        finishDownload(2, with: Data(count: 200))

        XCTAssertTrue(manager.totalStorageBytes <= 800, "Total (\(manager.totalStorageBytes)) should stay within the limit")
        XCTAssertFalse(manager.savedArticles().contains(where: { $0.title == "Evict Art 1" }),
                       "Oldest article should be evicted first when images push the total over the limit")
        XCTAssertTrue(imageStore.removed.contains(article1.identifier))
    }

    func testMultipleAsyncImageUpdatesEnforceBudgetCumulatively() {
        let manager = makeManager(limitBytes: 600)
        manager.save(Article.sample(title: "Cumulative 1", url: "https://example.com/cum1"))
        manager.save(Article.sample(title: "Cumulative 2", url: "https://example.com/cum2"))
        XCTAssertEqual(manager.savedArticles().count, 2)

        finishDownload(0, with: Data(count: 50))
        XCTAssertTrue(manager.totalStorageBytes <= 600, "First small image should not trigger eviction")
        XCTAssertEqual(manager.savedArticles().count, 2)

        finishDownload(1, with: Data(count: 300))
        XCTAssertTrue(manager.totalStorageBytes <= 600,
                      "Total (\(manager.totalStorageBytes)) must stay within the limit after cumulative updates")
    }

    // MARK: - Widget Sync

    func testSavedArticlesArePublishedToTheWidgetOnEveryChange() {
        let widgetSync = MockWidgetSyncManager()
        let manager = makeManager(widgetSync: widgetSync)
        XCTAssertEqual(widgetSync.savedUpdates, [[]], "The widget learns the saved list as soon as the manager loads it")

        let article = Article.sample(title: "Widget Article", url: "https://example.com/widget")
        manager.save(article)
        XCTAssertEqual(widgetSync.savedUpdates.last?.map(\.title), ["Widget Article"])

        manager.remove(article)
        XCTAssertEqual(widgetSync.savedUpdates.last, [])
    }
}
