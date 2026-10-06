import Foundation
import XCGLogger

/// Fetches and decodes the articles feed.
final class ArticlesProvider: ArticlesProviderProtocol {
    private let client: NetworkClientProtocol
    private let decoder: JSONDecoder
    private let logger: XCGLogger

    init(client: NetworkClientProtocol, decoder: JSONDecoder = JSONDecoder(), logger: XCGLogger) {
        self.client = client
        self.decoder = decoder
        self.logger = logger
    }

    func fetchArticles() async throws -> [Article] {
        let data = try await client.data(from: .articles)

        let response: ArticlesResponse
        do {
            response = try decoder.decode(ArticlesResponse.self, from: data)
        } catch {
            logger.error("Articles payload is not valid JSON for the expected schema: \(error)")
            throw NetworkError.invalidResponse
        }

        let articles = response.articles.filter(\.hasDisplayableContent)
        let dropped = response.articles.count - articles.count
        if dropped > 0 {
            logger.warning("Dropped \(dropped) article(s) without any displayable content")
        }
        logger.debug("Decoded \(articles.count) article(s)")
        return articles
    }
}
