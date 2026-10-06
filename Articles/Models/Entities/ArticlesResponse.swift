import Foundation

/// Top-level envelope returned by the articles endpoint.
struct ArticlesResponse: Codable {
    let status: String?
    let totalResults: Int?
    let articles: [Article]

    init(status: String? = nil, totalResults: Int? = nil, articles: [Article]) {
        self.status = status
        self.totalResults = totalResults
        self.articles = articles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        totalResults = try? container.decodeIfPresent(Int.self, forKey: .totalResults)
        // A missing or malformed `articles` key is a genuinely invalid payload
        // and is allowed to throw; individual broken elements are skipped.
        articles = try container.decode(LossyArray<Article>.self, forKey: .articles).elements
    }
}
