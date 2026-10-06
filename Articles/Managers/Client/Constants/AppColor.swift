import UIKit

/// Colours from the Figma file, stored in the asset catalogue.
enum AppColor {
    /// Screen background of the list – `#FFFFFF`.
    static let background = color(named: "Background")
    /// Article card and detail header surface – `#233D46`.
    static let card = color(named: "Card")
    /// "Read More" button and card glow – `#195A94`.
    static let accent = color(named: "Accent")
    /// Screen title and header icons – `#000000`.
    static let textPrimary = color(named: "TextPrimary")
    /// Text on dark surfaces – `#FFFFFF`.
    static let textOnCard = color(named: "TextOnCard")
    /// Date on a card – `#969696`.
    static let textMuted = color(named: "TextMuted")
    /// Detail screen background – `#F3F3F3`.
    static let detailBackground = color(named: "DetailBackground")
    /// Detail body copy – `#8C8E98`.
    static let detailBody = color(named: "DetailBody")
    /// Detail timestamp – `#A7AEC1`.
    static let detailMeta = color(named: "DetailMeta")
    /// Full-screen state background – `#DAD9D9`.
    static let offlineBackground = color(named: "OfflineBackground")
    /// State illustration – `#222222`.
    static let offlineIcon = color(named: "OfflineIcon")
    /// State message – black at 60 %.
    static let offlineMessage = color(named: "OfflineMessage")
    /// "Retry" pill – `#ECECEC`.
    static let retryBackground = color(named: "RetryBackground")
    /// Surface behind the image placeholder – `#F8F8F8`.
    static let placeholderBackground = color(named: "PlaceholderBackground")

    private static func color(named name: String) -> UIColor {
        guard let color = UIColor(named: name) else {
            assertionFailure("Missing colour asset: \(name)")
            return .systemGray
        }
        return color
    }
}
