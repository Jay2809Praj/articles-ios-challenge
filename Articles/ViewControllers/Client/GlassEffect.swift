import UIKit

/// Liquid Glass on iOS 26, with a material blur standing in on iOS 18–25.
enum GlassEffect {
    enum Shape {
        case capsule
        case rounded(CGFloat)
    }

    /// Creates an effect view rendering glass where the system supports it.
    /// - Parameters:
    ///   - tint: Optional colour cast applied to the glass.
    ///   - isInteractive: Lets the glass react to touches (iOS 26 only).
    ///   - fallbackStyle: Blur used on systems without Liquid Glass.
    static func makeView(
        tint: UIColor? = nil,
        isInteractive: Bool = false,
        fallbackStyle: UIBlurEffect.Style = .systemThinMaterial
    ) -> UIVisualEffectView {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.tintColor = tint
            effect.isInteractive = isInteractive
            return UIVisualEffectView(effect: effect)
        }
        return UIVisualEffectView(effect: UIBlurEffect(style: fallbackStyle))
    }

    /// Rounds an effect view. Glass needs the corner configuration API to
    /// refract correctly; the blur fallback is simply clipped.
    static func apply(_ shape: Shape, to view: UIVisualEffectView) {
        if #available(iOS 26.0, *) {
            switch shape {
            case .capsule:
                view.cornerConfiguration = .capsule()
            case .rounded(let radius):
                view.cornerConfiguration = .corners(radius: .fixed(radius))
            }
        } else {
            switch shape {
            case .capsule:
                view.layer.cornerRadius = min(view.bounds.width, view.bounds.height) / 2
            case .rounded(let radius):
                view.layer.cornerRadius = radius
            }
            view.layer.cornerCurve = .continuous
            view.clipsToBounds = true
        }
    }
}
