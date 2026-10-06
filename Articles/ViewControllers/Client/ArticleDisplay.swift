import Foundation

/// Everything the UI shows for an article, with the gaps in the data already
/// resolved: missing titles get a fallback, broken links become `nil`, and the
/// API's truncation markers are stripped from the body.
struct ArticleDisplay {
    let title: String
    /// "24 Oct,2021" – `nil` when the article has no usable date.
    let listDate: String?
    /// "10h ago", optionally followed by the author or publisher.
    let detailMeta: String?
    let hasDate: Bool
    let body: String
    let imageURL: URL?
    let webURL: URL?

    init(article: Article, now: Date = Date()) {
        title = article.title ?? article.description ?? Self.untitled
        listDate = ArticleDateFormatter.displayString(from: article.publishedAt)

        let age = ArticleDateFormatter.shortRelativeString(from: article.publishedAt, relativeTo: now)
        let byline = article.author ?? article.source?.name
        let meta = [age, byline].compactMap { $0 }
        detailMeta = meta.isEmpty ? nil : meta.joined(separator: "  ·  ")
        hasDate = age != nil

        body = Self.body(for: article)
        imageURL = ArticleLinkValidator.webURL(from: article.urlToImage)
        webURL = ArticleLinkValidator.webURL(from: article.url)
    }

    static let untitled = "Untitled article"
    static let noPreview = "No preview is available for this article."

    private static func body(for article: Article) -> String {
        let content = article.content.map(cleaned)
        var paragraphs: [String] = []

        // The description is only worth repeating when it is not already the
        // opening of the content or the fallback title.
        if let description = article.description, article.title != nil {
            let opening = String(description.prefix(40))
            if content?.hasPrefix(opening) != true {
                paragraphs.append(description)
            }
        }
        if let content, !content.isEmpty {
            paragraphs.append(content)
        }
        return paragraphs.isEmpty ? noPreview : paragraphs.joined(separator: "\n\n")
    }

    /// Removes the feed's "[+3029 chars]"-style truncation marker.
    private static func cleaned(_ content: String) -> String {
        content
            .replacingOccurrences(of: #"\s*\[\+\d+( chars\])?\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
