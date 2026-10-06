import Foundation

/// Network operations for the articles feed.
protocol ArticlesProviderProtocol {
    /// Fetches the latest list of articles.
    /// - Throws: `NetworkError` describing what went wrong.
    func fetchArticles() async throws -> [Article]
}
