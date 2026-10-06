import Foundation

extension Article {
    /// A stable identifier derived from the content, since the API provides none.
    var identifier: String {
        [url, publishedAt, title]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}
