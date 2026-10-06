import UIKit

/// Icons used across the app (SF Symbols).
enum AppIcon {
    static let grid = symbol("square.grid.2x2.fill")
    static let list = symbol("rectangle.grid.1x2.fill")
    static let search = symbol("magnifyingglass")
    static let calendar = symbol("calendar")
    static let readMore = symbol("arrow.right.circle.fill")
    static let back = symbol("chevron.left")
    static let share = symbol("square.and.arrow.up")
    static let safari = symbol("safari")
    static let imagePlaceholder = symbol("photo")
    static let imageUnavailable = symbol("photo.badge.exclamationmark")
    static let offline = symbol("wifi.slash")
    static let online = symbol("wifi")
    static let warning = symbol("exclamationmark.triangle.fill")
    static let author = symbol("person.fill")

    /// Symbol names, for the SwiftUI side.
    enum Name {
        static let offline = "wifi.slash"
        static let error = "exclamationmark.triangle"
        static let empty = "newspaper"
        static let noResults = "magnifyingglass"
        static let selectArticle = "doc.text.magnifyingglass"
        static let retry = "arrow.clockwise"
    }

    private static func symbol(_ name: String) -> UIImage {
        guard let image = UIImage(systemName: name) else {
            assertionFailure("Missing SF Symbol: \(name)")
            return UIImage()
        }
        return image
    }
}
