import UIKit

/// Typography from the Figma design.
///
/// Every font is returned through `UIFontMetrics`, so it scales with the
/// user's Dynamic Type setting. Pair it with
/// `adjustsFontForContentSizeCategory = true` on the label.
enum AppFont {
    /// Screen title – Roboto Condensed Bold 30.
    static var screenTitle: UIFont { scaled("RobotoCondensed-Bold", size: 30, style: .largeTitle, weight: .bold) }
    /// Card title – Roboto Medium 15.
    static var cardTitle: UIFont { scaled("Roboto-Medium", size: 15, style: .headline, weight: .medium) }
    /// Compact card title used in the grid layout – Roboto Medium 13.
    static var gridTitle: UIFont { scaled("Roboto-Medium", size: 13, style: .subheadline, weight: .medium) }
    /// Dates and metadata – Montserrat Regular 12.
    static var meta: UIFont { scaled("MontserratThin-Regular", size: 12, style: .caption1, weight: .regular) }
    /// Buttons – Montserrat Medium 13.
    static var button: UIFont { scaled("MontserratThin-Medium", size: 13, style: .callout, weight: .medium) }
    /// Source badge – Montserrat Medium 11.
    static var badge: UIFont { scaled("MontserratThin-Medium", size: 11, style: .caption2, weight: .medium) }
    /// Detail headline – Roboto Condensed Bold 26.
    static var detailTitle: UIFont { scaled("RobotoCondensed-Bold", size: 26, style: .title1, weight: .bold) }
    /// Detail lead paragraph – Roboto Medium 16.
    static var lead: UIFont { scaled("Roboto-Medium", size: 16, style: .body, weight: .medium) }
    /// Detail body – Roboto Regular 15.
    static var body: UIFont { scaled("Roboto-Regular", size: 15, style: .body, weight: .regular) }
    /// Banners and toasts – Roboto Medium 13.
    static var banner: UIFont { scaled("Roboto-Medium", size: 13, style: .footnote, weight: .medium) }

    /// Line height the design uses for the card title (24 pt at 15 pt text).
    static let cardTitleLineHeightMultiple: CGFloat = 24.0 / 15.0

    private static func scaled(
        _ name: String,
        size: CGFloat,
        style: UIFont.TextStyle,
        weight: UIFont.Weight
    ) -> UIFont {
        // Falling back to the system font keeps the app usable if a font file
        // ever goes missing from the bundle.
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
