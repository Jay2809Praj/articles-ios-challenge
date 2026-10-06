import Foundation

/// Persists the last successfully loaded list of articles.
protocol ArticlesCacheProtocol {
    func save(_ articles: [Article])
    func load() -> CachedArticles?
    func clear()
}
