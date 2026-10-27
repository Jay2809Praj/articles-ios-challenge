@testable import Articles
import UIKit
import XCTest

final class BannerPresenterTests: XCTestCase {
    private var host: UIView!
    private var presenter: BannerPresenter!

    override func setUp() {
        super.setUp()
        host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        presenter = BannerPresenter(hostView: host)
    }

    private var banner: StatusBannerView? {
        host.subviews.compactMap { $0 as? StatusBannerView }.first
    }

    func testPinnedBannerLeavesWhenUnpinned() {
        presenter.pin(.offline(savedAgo: nil))
        XCTAssertEqual(banner?.alpha, 1)

        presenter.unpin()

        XCTAssertEqual(banner?.alpha, 0)
    }

    func testBannerPinnedDuringAToastStillLeavesWhenUnpinned() {
        // "Back online", then the next request fails and the offline banner
        // is pinned before the toast has gone.
        presenter.toast(.backOnline)
        presenter.pin(.offline(savedAgo: "2m ago"))
        XCTAssertEqual(banner?.content, .offline(savedAgo: "2m ago"))

        // Switching to Saved unpins it straight away.
        presenter.unpin()

        XCTAssertEqual(banner?.alpha, 0, "The offline banner must not stay stuck on screen")
    }

    func testUnpinDuringAToastLetsTheToastFinish() {
        presenter.toast(.backOnline)

        presenter.unpin()

        XCTAssertEqual(banner?.alpha, 1, "The toast leaves on its own timer")
        XCTAssertEqual(banner?.content, .backOnline)
    }
}
