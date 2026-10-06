import Foundation

/// Stores favourite article identifiers in `UserDefaults`.
final class FavoritesManager: FavoritesManagerProtocol {
    private let defaults: UserDefaults
    private let key = AppConstants.Favorites.storageKey
    private var identifiers: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        identifiers = Set(defaults.stringArray(forKey: AppConstants.Favorites.storageKey) ?? [])
    }

    func isFavorite(_ article: Article) -> Bool {
        identifiers.contains(article.identifier)
    }

    @discardableResult
    func toggleFavorite(_ article: Article) -> Bool {
        let identifier = article.identifier
        let isFavorite = !identifiers.contains(identifier)
        if isFavorite {
            identifiers.insert(identifier)
        } else {
            identifiers.remove(identifier)
        }
        defaults.set(identifiers.sorted(), forKey: key)
        return isFavorite
    }
}
