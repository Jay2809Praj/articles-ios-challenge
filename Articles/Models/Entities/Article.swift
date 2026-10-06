import Foundation

/// A single article as delivered by the API.
///
/// The feed is unreliable by design: every field can be missing, `null`, empty
/// or of an unexpected type. Decoding therefore never throws for an individual
/// field – anything unusable simply becomes `nil` and the UI decides how to
/// present the gap.
struct Article: Codable, Hashable {
    let source: ArticleSource?
    let author: String?
    let title: String?
    let description: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: String?
    let content: String?

    init(
        source: ArticleSource? = nil,
        author: String? = nil,
        title: String? = nil,
        description: String? = nil,
        url: String? = nil,
        urlToImage: String? = nil,
        publishedAt: String? = nil,
        content: String? = nil
    ) {
        self.source = source
        self.author = author
        self.title = title
        self.description = description
        self.url = url
        self.urlToImage = urlToImage
        self.publishedAt = publishedAt
        self.content = content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = try? container.decodeIfPresent(ArticleSource.self, forKey: .source)
        author = container.decodeCleanString(forKey: .author)
        title = container.decodeCleanString(forKey: .title)
        description = container.decodeCleanString(forKey: .description)
        url = container.decodeCleanString(forKey: .url)
        urlToImage = container.decodeCleanString(forKey: .urlToImage)
        publishedAt = container.decodeCleanString(forKey: .publishedAt)
        content = container.decodeCleanString(forKey: .content)
    }

    /// An article with nothing to show and nowhere to go is noise, not content.
    var hasDisplayableContent: Bool {
        title != nil || description != nil || content != nil
    }
}
