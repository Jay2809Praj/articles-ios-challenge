import UIKit

/// Typography from the Figma file.
///
/// Every font is routed through `UIFontMetrics`, so it scales with the user's
/// Dynamic Type setting. Pair it with `adjustsFontForContentSizeCategory`.
enum AppFont {
    /// Screen title – Roboto Condensed Black 30.
    static var screenTitle: UIFont { scaled("RobotoCondensed-Black", 30, .largeTitle, .black) }
    /// Card title – Roboto SemiBold 16 (24 pt line height).
    static var cardTitle: UIFont { scaled("Roboto-SemiBold", 16, .headline, .semibold) }
    /// Card date – Montserrat Regular 12.
    static var cardDate: UIFont { scaled("MontserratThin-Regular", 12, .caption1, .regular) }
    /// Card and detail buttons – Montserrat SemiBold 13.
    static var button: UIFont { scaled("MontserratThin-SemiBold", 13, .callout, .semibold) }
    /// Detail navigation title – Roboto Medium 20.
    static var navigationTitle: UIFont { scaled("Roboto-Medium", 20, .title3, .medium) }
    /// Detail headline – Roboto Bold 24.
    static var detailTitle: UIFont { scaled("Roboto-Bold", 24, .title1, .bold) }
    /// Detail timestamp – Roboto Light 14.
    static var detailMeta: UIFont { scaled("Roboto-Light", 14, .footnote, .light) }
    /// Detail body – Roboto Regular 16.
    static var detailBody: UIFont { scaled("Roboto-Regular", 16, .body, .regular) }
    /// State title – Roboto Bold 18.
    static var stateTitle: UIFont { scaled("Roboto-Bold", 18, .headline, .bold) }
    /// State message – Roboto Light 18.
    static var stateMessage: UIFont { scaled("Roboto-Light", 18, .body, .light) }
    /// "Retry" pill – Roboto Bold 16.
    static var stateButton: UIFont { scaled("Roboto-Bold", 16, .callout, .bold) }
    /// Banners and the search field – Roboto Medium 14.
    static var banner: UIFont { scaled("Roboto-Medium", 14, .footnote, .medium) }

    /// Tracking of the screen title, in points.
    static let screenTitleKerning: CGFloat = -0.165
    /// Tracking of the card date, in points (12 % of 12 pt).
    static let cardDateKerning: CGFloat = 1.44
    /// Card title: 24 pt lines at 16 pt text.
    static let cardTitleLineHeight: CGFloat = 24.0 / 16.0
    /// Detail headline: 130 %.
    static let detailTitleLineHeight: CGFloat = 1.3
    /// Detail body: 180 %.
    static let detailBodyLineHeight: CGFloat = 1.8

    private static func scaled(
        _ name: String,
        _ size: CGFloat,
        _ style: UIFont.TextStyle,
        _ weight: UIFont.Weight
    ) -> UIFont {
        // Falling back to the system font keeps the app usable if a font file
        // ever goes missing from the bundle.
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
