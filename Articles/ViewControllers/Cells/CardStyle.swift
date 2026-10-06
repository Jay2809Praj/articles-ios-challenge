import UIKit

/// The look shared by every article card: dark rounded surface with a soft
/// accent-coloured glow, plus a subtle press animation.
enum CardStyle {
    static func apply(to cell: UICollectionViewCell, cardView: UIView) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        cardView.backgroundColor = AppColor.card
        cardView.layer.cornerRadius = AppMetrics.Card.cornerRadius
        cardView.layer.cornerCurve = .continuous

        cell.clipsToBounds = false
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = AppColor.accent.cgColor
        cell.layer.shadowOpacity = AppMetrics.Card.shadowOpacity
        cell.layer.shadowRadius = AppMetrics.Card.shadowRadius
        cell.layer.shadowOffset = .zero
    }

    /// Keeps the glow and the keyboard-focus halo on the card's rounded shape.
    /// Call from `layoutSubviews`.
    static func updateShape(of cell: UICollectionViewCell) {
        let radius = AppMetrics.Card.cornerRadius
        cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: radius).cgPath
        cell.focusEffect = UIFocusHaloEffect(roundedRect: cell.bounds, cornerRadius: radius, curve: .continuous)
    }

    static func animateHighlight(of cell: UICollectionViewCell, isHighlighted: Bool) {
        UIView.animate(
            withDuration: isHighlighted ? 0.12 : 0.3,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            cell.transform = isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
}
