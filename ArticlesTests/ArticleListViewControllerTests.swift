@testable import Articles
import Swinject
import UIKit
import XCTest

/// Drives the real list screen, built by `ViewControllerFactory`, against
/// mocked data and connectivity.
final class ArticleListViewControllerTests: XCTestCase {
    private let suiteName = "ArticleListViewControllerTests"
    private var provider: MockArticlesProvider!
    private var cache: MockArticlesCache!
    private var reachability: MockReachabilityProvider!
    private var favorites: FavoritesManager!
    private var router: StubRouter!
    private var window: UIWindow!
    private var viewController: ArticleListViewController!

    override func setUp() {
        super.setUp()
        provider = MockArticlesProvider()
        cache = MockArticlesCache()
        reachability = MockReachabilityProvider()
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        favorites = FavoritesManager(
            defaults: defaults,
            storageName: suiteName,
            imageStore: MockSavedImageStore(),
            imageDownloader: { _, completion in completion(nil) },
            logger: .silent
        )
        favorites.clearAll()
        router = StubRouter()
    }

    override func tearDown() {
        window?.isHidden = true
        window = nil
        viewController = nil
        favorites.clearAll()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func showList() {
        let container = Container()
        let manager = ArticlesManager(provider: provider, cache: cache, pageSize: 10, logger: .silent)
        let connectivity = ConnectivityManager(provider: reachability)
        container.register(ArticlesManagerProtocol.self) { _ in manager }
        container.register(ConnectivityManagerProtocol.self) { _ in connectivity }
        container.register(FavoritesManagerProtocol.self) { [favorites] _ in favorites! }

        viewController = ViewControllerFactory(resolver: container).makeArticleList(router: router)
        // Attached to the host app's scene so animations really run.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.view.layoutIfNeeded()
    }

    /// Spins the main run loop until `condition` holds or time runs out.
    @discardableResult
    private func waitUntil(timeout: TimeInterval = 3, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    private func spin(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private var collectionView: UICollectionView {
        viewController.value(forKey: "collectionView") as! UICollectionView
    }

    private var stateContainer: UIView {
        viewController.value(forKey: "stateContainer") as! UIView
    }

    private var headerView: ArticleListHeaderView {
        viewController.value(forKey: "headerView") as! ArticleListHeaderView
    }

    private var shownCount: Int {
        collectionView.numberOfItems(inSection: 0)
    }

    // MARK: - Reconnecting

    func testReconnectKeepsFreshPagesAndSendsNoRequest() {
        provider.feed = .success(.samples(25))
        showList()
        XCTAssertTrue(waitUntil { self.shownCount == 10 })

        reachability.simulate(reachable: false)
        reachability.simulate(reachable: true)
        spin(0.3)

        XCTAssertEqual(provider.requestedPages, [1], "The list from the network is still fresh")
        XCTAssertEqual(shownCount, 10)
    }

    func testReconnectReloadsCachedContent() {
        cache.save([.sample(title: "Saved earlier")])
        provider.feed = .failure(.offline)
        reachability.isReachable = false
        showList()
        XCTAssertTrue(waitUntil { self.provider.requestedPages == [1] })
        spin(0.1)

        provider.feed = .success([.sample(title: "Fresh")])
        reachability.simulate(reachable: true)

        XCTAssertTrue(waitUntil { self.provider.requestedPages == [1, 1] })
        XCTAssertTrue(waitUntil { (self.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? ArticleCardCell) != nil })
        XCTAssertEqual(shownCount, 1)
    }

    func testReconnectRetriesAFailedEmptyScreen() {
        provider.feed = .failure(.offline)
        reachability.isReachable = false
        showList()
        XCTAssertTrue(waitUntil { self.provider.requestedPages == [1] })
        spin(0.1)

        provider.feed = .success(.samples(3))
        reachability.simulate(reachable: true)

        XCTAssertTrue(waitUntil { self.shownCount == 3 })
        XCTAssertEqual(provider.requestedPages, [1, 1])
    }

    // MARK: - Full-area state

    func testNoResultsStateSurvivesQuickTypingAndDeleting() {
        provider.feed = .success(.samples(5))
        showList()
        XCTAssertTrue(waitUntil { self.shownCount == 5 })
        spin(0.4)
        XCTAssertTrue(stateContainer.isHidden)

        // Faster than the 0.25 s cross-fade: no match, a match, no match.
        viewController.headerView(headerView, didChangeSearchText: "zzzz")
        spin(0.05)
        viewController.headerView(headerView, didChangeSearchText: "")
        spin(0.05)
        viewController.headerView(headerView, didChangeSearchText: "zzzz")
        spin(0.6)

        XCTAssertEqual(shownCount, 0)
        XCTAssertFalse(stateContainer.isHidden, "\"No results\" must be on screen")
        XCTAssertEqual(stateContainer.alpha, 1)
    }

    func testContentReturnsAfterQuickDeleteAndRetype() {
        provider.feed = .success(.samples(5))
        showList()
        XCTAssertTrue(waitUntil { self.shownCount == 5 })
        spin(0.4)

        viewController.headerView(headerView, didChangeSearchText: "zzzz")
        spin(0.05)
        viewController.headerView(headerView, didChangeSearchText: "")
        spin(0.6)

        XCTAssertEqual(shownCount, 5)
        XCTAssertTrue(stateContainer.isHidden)
        XCTAssertFalse(collectionView.isHidden)
        XCTAssertEqual(collectionView.alpha, 1)
    }
}

private final class StubRouter: ArticleRouting {
    func showDetail(for article: Article, sourceViewProvider: @escaping () -> UIView?) {}
    func closeDetail() {}
    func openInBrowser(_ url: URL) {}
}
