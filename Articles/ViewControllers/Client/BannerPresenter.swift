import UIKit

/// Shows `StatusBannerView`s at the bottom of a host view: either pinned until
/// dismissed (offline) or as a toast that leaves on its own.
final class BannerPresenter {
    private weak var hostView: UIView?
    /// A view at the bottom of the host the banner must stay clear of.
    private weak var anchorView: UIView?
    private let banner = StatusBannerView()
    private var bottomConstraint: NSLayoutConstraint?
    private var dismissWorkItem: DispatchWorkItem?
    /// Content to return to once a transient toast has gone.
    private var pinnedContent: StatusBannerView.Content?

    private let visibleOffset: CGFloat = -16
    private let hiddenOffset: CGFloat = 160
    private let toastDuration: TimeInterval = 3

    /// - Parameters:
    ///   - hostView: The view the banner is added to.
    ///   - anchorView: Optional subview of `hostView` to float above, such as
    ///     a bottom button. Defaults to the bottom safe area.
    init(hostView: UIView, above anchorView: UIView? = nil) {
        self.hostView = hostView
        self.anchorView = anchorView
    }

    /// Shows a banner that stays until `unpin()` is called.
    func pin(_ content: StatusBannerView.Content) {
        pinnedContent = content
        dismissWorkItem?.cancel()
        present(content)
    }

    func unpin() {
        pinnedContent = nil
        if dismissWorkItem == nil {
            dismiss()
        }
    }

    /// Shows a banner briefly, then restores the pinned banner if there is one.
    func toast(_ content: StatusBannerView.Content) {
        present(content)
        UIAccessibility.post(notification: .announcement, argument: content.message)

        dismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dismissWorkItem = nil
            if let pinnedContent = self.pinnedContent {
                self.present(pinnedContent)
            } else {
                self.dismiss()
            }
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + toastDuration, execute: workItem)
    }

    // MARK: - Presentation

    private func present(_ content: StatusBannerView.Content) {
        guard let hostView else { return }
        installIfNeeded(in: hostView)

        if banner.content != content {
            UIView.transition(with: banner, duration: 0.2, options: .transitionCrossDissolve) {
                self.banner.content = content
            }
        }

        hostView.bringSubviewToFront(banner)
        bottomConstraint?.constant = visibleOffset
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.4,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.banner.alpha = 1
            hostView.layoutIfNeeded()
        }
    }

    private func dismiss() {
        guard let hostView, banner.superview != nil else { return }
        bottomConstraint?.constant = hiddenOffset
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseIn]
        ) {
            self.banner.alpha = 0
            hostView.layoutIfNeeded()
        }
    }

    private func installIfNeeded(in hostView: UIView) {
        guard banner.superview == nil else { return }

        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.alpha = 0
        hostView.addSubview(banner)

        let bottom = banner.bottomAnchor.constraint(
            equalTo: anchorView?.topAnchor ?? hostView.safeAreaLayoutGuide.bottomAnchor,
            constant: hiddenOffset
        )
        bottomConstraint = bottom
        NSLayoutConstraint.activate([
            bottom,
            // The safe area keeps the banner clear of the iPad sidebar, which
            // floats above the detail column on iOS 26.
            banner.centerXAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.centerXAnchor),
            banner.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])
        hostView.layoutIfNeeded()
    }
}
