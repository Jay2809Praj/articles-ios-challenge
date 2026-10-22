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
}
