import SwiftUI
import UIKit

/// Hosts the SwiftUI `ContentStateView` so UIKit screens can embed it as a
/// child view controller.
final class ContentStateViewController: UIHostingController<ContentStateView> {
    private var onRetry: (() -> Void)?

    init(kind: ContentStateView.Kind, onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
        super.init(rootView: ContentStateView(kind: kind, onRetry: onRetry))
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("ContentStateViewController is created in code")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    func show(_ kind: ContentStateView.Kind) {
        guard rootView.kind != kind else { return }
        rootView = ContentStateView(kind: kind, onRetry: onRetry)
    }
}

extension UIViewController {
    /// Adds `child` as a child view controller filling `container`.
    func embed(_ child: UIViewController, in container: UIView) {
        addChild(child)
        container.addSubview(child.view)
        child.view.pinEdges(to: container)
        child.didMove(toParent: self)
    }
}
