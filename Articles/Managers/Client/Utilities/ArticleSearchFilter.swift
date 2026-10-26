import Foundation

/// Filters articles by a free-text query.
enum ArticleSearchFilter {
    static func filter(_ articles: [Article], matching query: String) -> [Article] {
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return articles }

        return articles.filter { article in
            let haystack = [article.title, article.description, article.author, article.source?.name]
                .compactMap { $0 }
                .joined(separator: " ")
            return terms.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        }
    }
}
