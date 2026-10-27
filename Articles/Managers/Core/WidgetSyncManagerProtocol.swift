import Foundation

/// Keeps the home screen widget in step with what the app has loaded, saved
/// and read.
protocol WidgetSyncManagerProtocol: AnyObject {
    /// The most recent list the app obtained, from the network or the cache.
    func updateLatestArticles(_ articles: [Article])

    /// The articles the user has saved for later, most recent first.
    func updateSavedArticles(_ articles: [Article])

    /// The article the user just opened; the widget shows it first.
    func updateLastOpenedArticle(_ article: Article)

    /// The article last opened, kept across launches. The widget can show it
    /// after it has left the feed cache, so deep links look here too.
    var lastOpenedArticle: Article? { get }
}
