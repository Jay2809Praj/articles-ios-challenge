import UIKit

/// Navigation the article screens can ask for, without knowing how the app
/// is structured around them.
protocol ArticleRouting: AnyObject {
    /// Shows the detail screen for an article.
    /// - Parameter sourceViewProvider: Returns the view the transition should
    ///   grow from and shrink back into, if it is still on screen.
    func showDetail(for article: Article, sourceViewProvider: @escaping () -> UIView?)
    func closeDetail()
    /// Opens the full article in an in-app Safari view.
    func openInBrowser(_ url: URL)
}
