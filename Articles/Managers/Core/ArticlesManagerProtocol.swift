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
    /// Every article loaded so far, first page first.
    let articles: [Article]
    let origin: ArticlesOrigin
    /// Set when the network request failed. `articles` may still hold cached
    /// content in that case.
    let error: NetworkError?
    /// `true` when `loadNextPage()` can add more articles.
    let hasMore: Bool

    var isStale: Bool {
        if case .cache = origin { return true }
        return false
    }

    /// Whether this list is worth asking for again once the connection
    /// returns: it came from disk, the request failed, or there is nothing to
    /// show. A fresh list from the network is kept, with its loaded pages.
    var needsRefreshWhenOnline: Bool {
        isStale || error != nil || articles.isEmpty
    }
}

/// The single entry point view controllers use to obtain articles.
protocol ArticlesManagerProtocol {
    /// The first page of the list stored on disk, if any – available
    /// synchronously so the UI can paint content before the first request
    /// completes. Later pages of that list come from `loadNextPage()`.
    func cachedArticles() -> ArticlesLoadResult?

    /// Requests the first page afresh, falling back to the cached list on
    /// failure. Anything loaded by earlier calls is discarded. Calls made
    /// while page 1 is already loading wait for that request instead of
    /// sending another one.
    func loadArticles() async -> ArticlesLoadResult

    /// Appends the next page to what is loaded. When nothing more is available
    /// the current state is returned unchanged.
    func loadNextPage() async -> ArticlesLoadResult

    /// Everything stored on disk, regardless of paging – for lookups such as
    /// opening an article from a deep link.
    func allCachedArticles() -> [Article]
}
