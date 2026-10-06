import SafariServices
import UIKit

/// Owns the app's navigation structure: a split view with the list in the
/// primary column and the selected article in the secondary one. On compact
/// widths the split view collapses and the detail is pushed instead.
final class AppRouter: NSObject, ArticleRouting {
    private let factory: ViewControllerFactoryProtocol

    private lazy var primaryNavigation = makeNavigationController(
        root: factory.makeArticleList(router: self)
    )
    private lazy var secondaryNavigation = makeNavigationController(
        root: ContentStateViewController(kind: .selectArticle)
    )
    private lazy var splitViewController: UISplitViewController = {
        let split = UISplitViewController(style: .doubleColumn)
        split.delegate = self
        split.preferredDisplayMode = .oneBesideSecondary
        split.preferredSplitBehavior = .tile
        split.presentsWithGesture = false
        split.displayModeButtonVisibility = .never
        split.preferredPrimaryColumnWidthFraction = 0.42
        split.minimumPrimaryColumnWidth = 360
        split.maximumPrimaryColumnWidth = 440
        split.setViewController(primaryNavigation, for: .primary)
        split.setViewController(secondaryNavigation, for: .secondary)
        return split
    }()

    /// `true` while an article is shown in the secondary column.
    private var isShowingArticleInSecondary = false

    init(factory: ViewControllerFactoryProtocol) {
        self.factory = factory
    }

    func makeRootViewController() -> UIViewController {
        splitViewController
    }

    // MARK: - ArticleRouting

    func showDetail(for article: Article, sourceViewProvider: @escaping () -> UIView?) {
        let detail = factory.makeArticleDetail(for: article, router: self)

        if splitViewController.isCollapsed {
            detail.preferredTransition = makeZoomTransition(sourceViewProvider: sourceViewProvider)
            primaryNavigation.pushViewController(detail, animated: true)
        } else {
            isShowingArticleInSecondary = true
            UIView.transition(
                with: secondaryNavigation.view,
                duration: 0.25,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                self.secondaryNavigation.setViewControllers([detail], animated: false)
            }
        }
    }

    func closeDetail() {
        if primaryNavigation.viewControllers.count > 1 {
            primaryNavigation.popViewController(animated: true)
        } else {
            splitViewController.show(.primary)
        }
    }

    func openInBrowser(_ url: URL) {
        // SFSafariViewController throws for anything but http(s).
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }

        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = AppColor.accent
        safari.dismissButtonStyle = .close
        splitViewController.present(safari, animated: true)
    }

    // MARK: - Helpers

    private func makeNavigationController(root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        // Both screens draw their own headers, as in the design.
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
    }

    /// The card's image grows into the detail screen's hero image and shrinks
    /// back on dismissal; the system adds the interactive pinch/swipe-back.
    private func makeZoomTransition(sourceViewProvider: @escaping () -> UIView?) -> UIViewController.Transition {
        let options = UIViewController.Transition.ZoomOptions()
        options.alignmentRectProvider = { context in
            (context.zoomedViewController as? ArticleDetailViewController)?.heroImageFrame
        }
        return .zoom(options: options) { _ in sourceViewProvider() }
    }
}

// MARK: - UISplitViewControllerDelegate

extension AppRouter: UISplitViewControllerDelegate {
    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        // Without a selected article the secondary column only holds the
        // placeholder, which must never be what an iPhone launches into.
        isShowingArticleInSecondary ? .secondary : .primary
    }

    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        isShowingArticleInSecondary = false
    }
}
