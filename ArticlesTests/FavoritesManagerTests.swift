@testable import Articles
import XCTest

final class FavoritesManagerTests: XCTestCase {
    private let suiteName = "FavoritesManagerTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testToggleAddsAndRemoves() {
        let manager = FavoritesManager(defaults: defaults)
        let article = Article.sample()

        XCTAssertFalse(manager.isFavorite(article))
        XCTAssertTrue(manager.toggleFavorite(article))
        XCTAssertTrue(manager.isFavorite(article))
        XCTAssertFalse(manager.toggleFavorite(article))
        XCTAssertFalse(manager.isFavorite(article))
    }

    func testFavoritesPersistAcrossInstances() {
        let article = Article.sample()
        FavoritesManager(defaults: defaults).toggleFavorite(article)

        XCTAssertTrue(FavoritesManager(defaults: defaults).isFavorite(article))
    }
}
