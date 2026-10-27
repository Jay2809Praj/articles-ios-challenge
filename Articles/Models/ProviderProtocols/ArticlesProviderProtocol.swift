import Foundation

/// One page of the articles feed, the way a paginating server would answer.
struct ArticlesPage: Equatable {
    let articles: [Article]
    /// 1-based page number this answer is for.
    let page: Int
    /// `true` when a request for `page + 1` would return more articles.
    let hasMore: Bool
}

/// Network operations for the articles feed.
protocol ArticlesProviderProtocol {
    /// Fetches one page of articles.
    /// - Parameters:
    ///   - page: 1-based page number; page 1 always reflects the latest feed.
    ///   - pageSize: how many articles a page holds.
    /// - Throws: `NetworkError` describing what went wrong.
    func fetchArticles(page: Int, pageSize: Int) async throws -> ArticlesPage
}
