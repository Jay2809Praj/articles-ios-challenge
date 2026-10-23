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

    private static let cardSavedIcon = makeFavoriteIcon(isSaved: true, size: CGSize(width: 20, height: 16.5))
    private static let cardUnsavedIcon = makeFavoriteIcon(isSaved: false, size: CGSize(width: 20, height: 16.5))
    private static let gridSavedIcon = makeFavoriteIcon(isSaved: true, size: CGSize(width: 16, height: 13.5))
    private static let gridUnsavedIcon = makeFavoriteIcon(isSaved: false, size: CGSize(width: 16, height: 13.5))

    /// Returns a pre-rendered, cached template image of the favorite icon so it fits cleanly
    /// inside circular buttons without touching or being clipped by the edges.
    static func favoriteIcon(isSaved: Bool, size: CGSize = CGSize(width: 20, height: 16.5)) -> UIImage {
        if size.width <= 16 {
            return isSaved ? gridSavedIcon : gridUnsavedIcon
        } else {
            return isSaved ? cardSavedIcon : cardUnsavedIcon
        }
    }

    private static func makeFavoriteIcon(isSaved: Bool, size: CGSize) -> UIImage {
        let raw = isSaved ? favoriteRemove : favoriteAdd
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            raw.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysTemplate)
    }

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
