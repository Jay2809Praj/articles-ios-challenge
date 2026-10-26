import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard
            let windowScene = scene as? UIWindowScene,
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let router = appDelegate.container.resolve(AppRouter.self)
        else {
            return
        }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = AppColor.accent
        window.rootViewController = router.makeRootViewController()
        window.makeKeyAndVisible()
        self.window = window

        if let incomingURL = connectionOptions.urlContexts.first?.url {
            handleDeepLink(incomingURL)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    /// `articles://open?id=<identifier>` from the widget opens that article;
    /// `articles://open` alone simply brings the app forward.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "articles",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let router = appDelegate.container.resolve(AppRouter.self),
              let articlesManager = appDelegate.container.resolve(ArticlesManagerProtocol.self),
              let favoritesManager = appDelegate.container.resolve(FavoritesManagerProtocol.self)
        else {
            return
        }

        let queryItems = components.queryItems ?? []
        let identifier = queryItems.first(where: { $0.name == "id" })?.value
        let webURL = queryItems.first(where: { $0.name == "url" })?.value
        guard identifier != nil || webURL != nil else { return }

        // Saved articles stay available even when the feed cache is gone.
        let known = favoritesManager.savedArticles() + articlesManager.allCachedArticles()
        if let match = Self.article(in: known, identifier: identifier, webURL: webURL) {
            router.showArticleDetail(for: match)
            return
        }

        Task { @MainActor in
            let result = await articlesManager.loadArticles()
            if let match = Self.article(in: result.articles, identifier: identifier, webURL: webURL) {
                router.showArticleDetail(for: match)
            }
        }
    }

    private static func article(in articles: [Article], identifier: String?, webURL: String?) -> Article? {
        if let identifier, let match = articles.first(where: { $0.identifier == identifier }) {
            return match
        }
        if let webURL, let match = articles.first(where: { $0.url == webURL }) {
            return match
        }
        return nil
    }
}
