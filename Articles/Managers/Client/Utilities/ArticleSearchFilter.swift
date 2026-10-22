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

/// Pure logic for slicing articles into paginated chunks for simulated infinite scrolling.
enum ArticlePaginator {
    /// Slices the given articles up to the current page number.
    static func paginate(_ articles: [Article], page: Int, pageSize: Int = AppConstants.Pagination.pageSize) -> [Article] {
        guard page > 0, !articles.isEmpty else { return [] }
        let totalToShow = min(page * pageSize, articles.count)
        return Array(articles.prefix(totalToShow))
    }

    /// Determines if more pages exist beyond the currently displayed page.
    static func hasMorePages(totalCount: Int, page: Int, pageSize: Int = AppConstants.Pagination.pageSize) -> Bool {
        guard totalCount > 0, page > 0 else { return false }
        return (page * pageSize) < totalCount
    }
}
