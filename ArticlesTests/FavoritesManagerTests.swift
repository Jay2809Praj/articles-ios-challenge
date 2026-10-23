@testable import Articles
import XCTest

final class FavoritesManagerTests: XCTestCase {
    private let suiteName = "FavoritesManagerTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent).clearAll()
    }

    override func tearDown() {
        FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent).clearAll()
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testToggleAddsAndRemoves() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        let article = Article.sample()

        XCTAssertFalse(manager.isFavorite(article))
        XCTAssertTrue(manager.toggleFavorite(article))
        XCTAssertTrue(manager.isFavorite(article))
        XCTAssertFalse(manager.toggleFavorite(article))
        XCTAssertFalse(manager.isFavorite(article))
    }

    func testFavoritesPersistAcrossInstances() {
        let article = Article.sample()
        let manager1 = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        manager1.toggleFavorite(article)

        let manager2 = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        XCTAssertTrue(manager2.isFavorite(article))
    }

    func testSaveStoresFullArticleModel() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        let article = Article.sample(title: "Detailed Article", description: "Rich Description", url: "https://example.com/1")

        manager.save(article)

        XCTAssertTrue(manager.isSaved(article))
        let savedList = manager.savedArticles()
        XCTAssertEqual(savedList.count, 1)
        XCTAssertEqual(savedList.first?.title, "Detailed Article")
        XCTAssertEqual(savedList.first?.description, "Rich Description")
    }

    func testSavedArticlesAreSortedMostRecentlySavedFirst() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        let first = Article.sample(title: "Article 1", url: "https://example.com/1")
        let second = Article.sample(title: "Article 2", url: "https://example.com/2")

        manager.save(first)
        manager.save(second)

        let saved = manager.savedArticles()
        XCTAssertEqual(saved.map(\.title), ["Article 2", "Article 1"])
    }

    func test50MBStorageLimitEvictsOldestArticleWhenExceeded() {
        // Each sample article encodes to ~270 bytes. Set limit to 600 bytes so 2 fit but 3 exceed.
        let limitBytes: Int64 = 600
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, storageLimitBytes: limitBytes, logger: .silent)

        var removedImages: [URL] = []
        manager.imageRemover = { url in
            removedImages.append(url)
        }

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
        XCTAssertFalse(removedImages.isEmpty)
    }

    func testRemoveArticleCleansUpImage() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        var removedImages: [URL] = []
        manager.imageRemover = { url in
            removedImages.append(url)
        }

        let article = Article.sample(title: "To Remove", url: "https://example.com/removable")
        manager.save(article)
        XCTAssertTrue(manager.isSaved(article))

        manager.remove(article)
        XCTAssertFalse(manager.isSaved(article))
        XCTAssertTrue(manager.savedArticles().isEmpty)
        XCTAssertEqual(removedImages.first?.absoluteString, "https://example.com/image.jpg")
    }

    func testClearAllRemovesAllArticles() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        manager.save(Article.sample(title: "A1", url: "https://example.com/1"))
        manager.save(Article.sample(title: "A2", url: "https://example.com/2"))
        XCTAssertEqual(manager.savedArticles().count, 2)

        manager.clearAll()
        XCTAssertTrue(manager.savedArticles().isEmpty)
        XCTAssertEqual(manager.totalStorageBytes, 0)
    }

    func testRapidTogglingMaintainsConsistentState() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
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

    func testSynchronousImageDownloaderDoesNotDeadlock() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        let article = Article.sample(title: "Sync Download", url: "https://example.com/syncdownload")

        // Simulate synchronous cache hits from Kingfisher (which previously caused deadlock)
        manager.imageDownloader = { _, completion in
            completion(45_000)
        }

        for _ in 1...10 {
            manager.save(article)
            XCTAssertTrue(manager.isSaved(article))
            manager.remove(article)
            XCTAssertFalse(manager.isSaved(article))
        }
    }

    func testConcurrentRapidTogglingNeverDeadlocks() {
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, logger: .silent)
        let article = Article.sample(title: "Concurrent", url: "https://example.com/concurrent")

        manager.imageDownloader = { _, completion in
            completion(25_000)
        }

        let group = DispatchGroup()
        for _ in 0..<6 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                for _ in 0..<20 {
                    manager.toggleSave(article)
                    _ = manager.isSaved(article)
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 5.0)
        XCTAssertEqual(result, .success, "Concurrent toggles deadlocked!")
    }

    // MARK: - Async Image Size Re-enforcement Tests

    func testAsyncImageSizeUpdateReEnforcesStorageLimit() {
        // Budget: 1000 bytes. Two articles fit when imageByteSize is 0.
        // When an async image download completes and pushes the total over limit,
        // the oldest article should be evicted.
        let limitBytes: Int64 = 1000
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, storageLimitBytes: limitBytes, logger: .silent)

        var completionBlocks: [(Int64) -> Void] = []
        var removedImages: [URL] = []

        manager.imageDownloader = { _, completion in
            // Capture the completion to call later (simulating async download)
            completionBlocks.append(completion)
        }
        manager.imageRemover = { url in
            removedImages.append(url)
        }

        let article1 = Article.sample(title: "Async Art 1", url: "https://example.com/async1")
        let article2 = Article.sample(title: "Async Art 2", url: "https://example.com/async2")

        manager.save(article1)
        manager.save(article2)

        // Both articles are saved. At this point imageByteSize = 0 for both.
        XCTAssertEqual(manager.savedArticles().count, 2)
        XCTAssertTrue(manager.totalStorageBytes < limitBytes, "Without images, both fit within budget")

        // Now simulate async image downloads completing with large sizes
        // Article 1's image: 600 bytes
        completionBlocks[0](600)

        // Still within budget (article bytes ~270 each + 600 image = ~1140? depends on encoding)
        // Let's trigger article 2's image download with a size that pushes total over 1000
        completionBlocks[1](500)

        // After both image sizes are updated, total should exceed 1000 bytes.
        // The re-enforcement should have evicted the oldest article(s) to stay within budget.
        XCTAssertTrue(manager.totalStorageBytes <= limitBytes,
                      "Total storage (\(manager.totalStorageBytes)) should not exceed limit (\(limitBytes)) after async image size updates")
    }

    func testSingleArticleExceedingBudgetIsEvicted() {
        // Budget: 500 bytes. Save one article. Its async image download returns a size
        // that alone exceeds the entire budget. The article should be removed.
        let limitBytes: Int64 = 500
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, storageLimitBytes: limitBytes, logger: .silent)

        var completionBlock: ((Int64) -> Void)?
        var removedImages: [URL] = []

        manager.imageDownloader = { _, completion in
            completionBlock = completion
        }
        manager.imageRemover = { url in
            removedImages.append(url)
        }

        let article = Article.sample(title: "Oversized Article", url: "https://example.com/oversized")
        manager.save(article)
        XCTAssertEqual(manager.savedArticles().count, 1)

        // Simulate image download completing with a size that makes the single article
        // exceed the entire budget (article bytes ~270 + 50000 image >> 500)
        completionBlock?(50_000)

        // The article should have been evicted because its total size > budget
        XCTAssertTrue(manager.savedArticles().isEmpty,
                      "Article whose total size exceeds the entire budget should be removed")
        XCTAssertEqual(manager.totalStorageBytes, 0)
        XCTAssertFalse(removedImages.isEmpty, "Oversized article's image should be cleaned up")
    }

    func testAsyncImageSizeUpdateEvictsOldestToMakeRoom() {
        // Budget: 800 bytes. Save 3 articles (small without images).
        // When image sizes arrive, the oldest should be evicted to stay within budget.
        let limitBytes: Int64 = 800
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, storageLimitBytes: limitBytes, logger: .silent)

        var completionBlocks: [(Int64) -> Void] = []
        var removedImages: [URL] = []

        manager.imageDownloader = { _, completion in
            completionBlocks.append(completion)
        }
        manager.imageRemover = { url in
            removedImages.append(url)
        }

        let article1 = Article.sample(title: "Evict Art 1", url: "https://example.com/evict1")
        let article2 = Article.sample(title: "Evict Art 2", url: "https://example.com/evict2")
        let article3 = Article.sample(title: "Evict Art 3", url: "https://example.com/evict3")

        manager.save(article1)
        manager.save(article2)
        manager.save(article3)

        // All 3 saved (article bytes only, no images yet)
        XCTAssertEqual(manager.savedArticles().count, 3)

        // Simulate image downloads completing
        completionBlocks[0](200)
        completionBlocks[1](200)
        completionBlocks[2](200)

        // After async updates, total would exceed 800 so evictions should occur
        let remaining = manager.savedArticles()
        XCTAssertTrue(manager.totalStorageBytes <= limitBytes,
                      "Total (\(manager.totalStorageBytes)) should stay within (\(limitBytes))")
        // Article 1 should be evicted first (oldest saved)
        XCTAssertFalse(remaining.contains(where: { $0.title == "Evict Art 1" }),
                       "Oldest article should be evicted first when async images push total over limit")
    }

    func testMultipleAsyncImageUpdatesEnforceBudgetCumulatively() {
        // Verify that the budget is checked after EVERY image size update, not just the first.
        let limitBytes: Int64 = 600
        let manager = FavoritesManager(defaults: defaults, storageName: suiteName, storageLimitBytes: limitBytes, logger: .silent)

        var completionBlocks: [(Int64) -> Void] = []

        manager.imageDownloader = { _, completion in
            completionBlocks.append(completion)
        }
        manager.imageRemover = { _ in }

        let article1 = Article.sample(title: "Cumulative 1", url: "https://example.com/cum1")
        let article2 = Article.sample(title: "Cumulative 2", url: "https://example.com/cum2")

        manager.save(article1)
        manager.save(article2)
        XCTAssertEqual(manager.savedArticles().count, 2)

        // First image update - small, should still fit
        completionBlocks[0](50)
        XCTAssertTrue(manager.totalStorageBytes <= limitBytes,
                      "First small image should not trigger eviction")

        // Second image update - large enough to push total over limit
        completionBlocks[1](300)

        // Budget should be enforced
        XCTAssertTrue(manager.totalStorageBytes <= limitBytes,
                      "Total (\(manager.totalStorageBytes)) must stay within (\(limitBytes)) after cumulative async updates")
    }
}
