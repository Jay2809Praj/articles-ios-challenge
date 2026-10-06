import Foundation

/// Keeps track of the articles the user saved with the heart button.
protocol FavoritesManagerProtocol {
    func isFavorite(_ article: Article) -> Bool

    /// Flips the favourite state of an article.
    /// - Returns: `true` when the article is a favourite after the call.
    @discardableResult
    func toggleFavorite(_ article: Article) -> Bool
}
