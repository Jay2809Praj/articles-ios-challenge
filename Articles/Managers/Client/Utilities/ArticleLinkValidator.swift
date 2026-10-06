import Foundation

/// Decides whether a string from the API is a link the app can safely open.
///
/// `SFSafariViewController` raises an exception for anything that is not
/// http(s), and Kingfisher wastes a request on malformed URLs, so every link
/// goes through here first.
enum ArticleLinkValidator {
    static func webURL(from string: String?) -> URL? {
        guard
            let string,
            !string.contains(where: \.isWhitespace),
            let components = URLComponents(string: string),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            host.contains("."),
            !host.hasPrefix("."),
            !host.hasSuffix(".")
        else {
            return nil
        }
        return components.url
    }
}
