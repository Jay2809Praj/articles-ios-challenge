import Foundation

/// Where a list of articles came from.
enum ArticlesOrigin: Equatable {
    /// Fresh from the API.
    case network
    /// Restored from disk; `savedAt` is when it was fetched.
    case cache(savedAt: Date)
}

/// The outcome of asking for articles. The UI never sees whether the cache or
/// the network was involved beyond what is described here.
struct ArticlesLoadResult: Equatable {
    let articles: [Article]
    let origin: ArticlesOrigin
    /// Set when the network request failed. `articles` may still hold cached
    /// content in that case.
    let error: NetworkError?

    var isStale: Bool {
        if case .cache = origin { return true }
        return false
    }
}

/// The single entry point view controllers use to obtain articles.
protocol ArticlesManagerProtocol {
    /// The list stored on disk, if any – available synchronously so the UI can
    /// paint content before the first request completes.
    func cachedArticles() -> ArticlesLoadResult?

    /// Requests fresh articles, falling back to the cached list on failure.
    func loadArticles() async -> ArticlesLoadResult
}
