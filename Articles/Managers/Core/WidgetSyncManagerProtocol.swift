import Foundation

/// Keeps the home screen widget in step with what the app has loaded and saved.
protocol WidgetSyncManagerProtocol: AnyObject {
    /// The most recent list the app obtained, from the network or the cache.
    func updateLatestArticles(_ articles: [Article])

    /// The articles the user has saved for later, most recent first.
    func updateSavedArticles(_ articles: [Article])
}
