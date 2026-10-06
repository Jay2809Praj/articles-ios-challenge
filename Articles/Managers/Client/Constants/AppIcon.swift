import UIKit

/// Icons and images exported from the Figma file.
enum AppIcon {
    static let grid = image(named: "IconGrid")
    static let list = image(named: "IconList")
    static let search = image(named: "IconSearch")
    static let calendar = image(named: "IconCalendar")
    static let readMore = image(named: "IconReadMore")
    static let back = image(named: "IconBack")
    static let clock = image(named: "IconClock")
    static let favoriteAdd = image(named: "IconFavoriteAdd")
    static let favoriteRemove = image(named: "IconFavoriteRemove")
    static let imagePlaceholder = image(named: "ImagePlaceholder")

    /// Asset and SF Symbol names, for the SwiftUI side.
    enum Name {
        static let offline = "IconOffline"
        static let retry = "IconRetry"
        static let error = "exclamationmark.triangle"
        static let empty = "newspaper"
        static let noResults = "magnifyingglass"
        static let selectArticle = "doc.text.magnifyingglass"
    }

    /// SF Symbols for UI the design does not cover (banners, search field).
    enum Symbol {
        static let offline = "wifi.slash"
        static let online = "wifi"
        static let warning = "exclamationmark.triangle.fill"
        static let favorite = "heart.fill"
        static let close = "xmark"
    }

    private static func image(named name: String) -> UIImage {
        guard let image = UIImage(named: name) else {
            assertionFailure("Missing image asset: \(name)")
            return UIImage()
        }
        return image
    }
}
