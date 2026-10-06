import UIKit

/// Colours from the Figma design, backed by the asset catalogue so each one
/// can carry a dark-mode variant.
enum AppColor {
    /// Top of the screen gradient (pure white in the design).
    static let backgroundTop = color(named: "BackgroundTop")
    /// Screen background behind the cards.
    static let background = color(named: "Background")
    /// Article card surface – `#233D46`.
    static let card = color(named: "Card")
    /// Image placeholder surface, one step lighter than the card.
    static let cardPlaceholder = color(named: "CardPlaceholder")
    /// "Read More" button – `#195A94`.
    static let accent = color(named: "Accent")
    static let textPrimary = color(named: "TextPrimary")
    static let textOnCard = color(named: "TextOnCard")
    /// Dates and other de-emphasised text on a card – `#919EA2`.
    static let textMuted = color(named: "TextMuted")
    static let textSecondary = color(named: "TextSecondary")

    private static func color(named name: String) -> UIColor {
        guard let color = UIColor(named: name) else {
            assertionFailure("Missing colour asset: \(name)")
            return .systemGray
        }
        return color
    }
}
