import Foundation
import XCGLogger

/// Coordinates the provider and the cache so the UI gets the best available
/// list of articles without knowing how it was obtained.
final class ArticlesManager: ArticlesManagerProtocol {
    private let provider: ArticlesProviderProtocol
    private let cache: ArticlesCacheProtocol
    private let logger: XCGLogger

    init(provider: ArticlesProviderProtocol, cache: ArticlesCacheProtocol, logger: XCGLogger) {
        self.provider = provider
        self.cache = cache
        self.logger = logger
    }

    func cachedArticles() -> ArticlesLoadResult? {
        guard let cached = cache.load(), !cached.articles.isEmpty else { return nil }
        return ArticlesLoadResult(articles: cached.articles, origin: .cache(savedAt: cached.savedAt), error: nil)
    }

    func loadArticles() async -> ArticlesLoadResult {
        do {
            let articles = try await provider.fetchArticles()
            // An empty answer is valid, but not worth replacing a usable cache with.
            if !articles.isEmpty {
                cache.save(articles)
            }
            return ArticlesLoadResult(articles: articles, origin: .network, error: nil)
        } catch {
            let networkError = (error as? NetworkError) ?? .unknown(description: error.localizedDescription)
            return fallback(for: networkError)
        }
    }

    private func fallback(for error: NetworkError) -> ArticlesLoadResult {
        if let cached = cache.load(), !cached.articles.isEmpty {
            logger.warning("Request failed (\(error)); serving \(cached.articles.count) cached article(s)")
            return ArticlesLoadResult(articles: cached.articles, origin: .cache(savedAt: cached.savedAt), error: error)
        }
        logger.error("Request failed (\(error)) and no cached articles are available")
        return ArticlesLoadResult(articles: [], origin: .network, error: error)
    }
}
