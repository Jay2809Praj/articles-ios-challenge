import UIKit

/// Shows `StatusBannerView`s at the bottom of a host view: either pinned until
/// dismissed (offline) or as a toast that leaves on its own.
final class BannerPresenter {
    private weak var hostView: UIView?
    private let banner = StatusBannerView()
    private var bottomConstraint: NSLayoutConstraint?
    private var dismissWorkItem: DispatchWorkItem?
    /// Content to return to once a transient toast has gone.
    private var pinnedContent: StatusBannerView.Content?

    private let visibleOffset: CGFloat = -16
    private let hiddenOffset: CGFloat = 96
    private let toastDuration: TimeInterval = 3

    init(hostView: UIView) {
        self.hostView = hostView
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
            equalTo: hostView.safeAreaLayoutGuide.bottomAnchor,
            constant: hiddenOffset
        )
        bottomConstraint = bottom
        NSLayoutConstraint.activate([
            bottom,
            banner.centerXAnchor.constraint(equalTo: hostView.centerXAnchor),
            banner.leadingAnchor.constraint(greaterThanOrEqualTo: hostView.leadingAnchor, constant: 16),
            banner.trailingAnchor.constraint(lessThanOrEqualTo: hostView.trailingAnchor, constant: -16)
        ])
        hostView.layoutIfNeeded()
    }
}
