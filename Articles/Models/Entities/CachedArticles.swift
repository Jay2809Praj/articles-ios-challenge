import Foundation

/// The last successfully loaded list, stamped with the moment it was stored.
struct CachedArticles: Codable {
    let articles: [Article]
    let savedAt: Date
}
