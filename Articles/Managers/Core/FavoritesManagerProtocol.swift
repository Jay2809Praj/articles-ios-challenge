import Foundation

/// Keeps track of the articles the user saved for reading offline later.
protocol FavoritesManagerProtocol: AnyObject {
    /// Checks whether an article is saved.
    func isFavorite(_ article: Article) -> Bool
    func isSaved(_ article: Article) -> Bool

    /// Saves an article with its full content and persists its image offline.
    func save(_ article: Article)

    /// Removes an article from saved storage and cleans up its cached image.
    func remove(_ article: Article)

    /// Flips the saved / favourite state of an article.
    /// - Returns: `true` when the article is saved after the call.
    @discardableResult
    func toggleFavorite(_ article: Article) -> Bool

    @discardableResult
    func toggleSave(_ article: Article) -> Bool

    /// Returns all saved articles sorted by most recently saved first.
    func savedArticles() -> [Article]

    /// Total storage currently used by saved articles and their images (in bytes).
    var totalStorageBytes: Int64 { get }

    /// Maximum storage limit in bytes (50 MB).
    var storageLimitBytes: Int64 { get }

    /// Clears all saved articles and cleans up storage.
    func clearAll()
}

extension FavoritesManagerProtocol {
    func isFavorite(_ article: Article) -> Bool {
        isSaved(article)
    }

    @discardableResult
    func toggleFavorite(_ article: Article) -> Bool {
        toggleSave(article)
    }
}
