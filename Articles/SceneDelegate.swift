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

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "articles" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let targetParam = components.queryItems?.first(where: { $0.name == "url" })?.value
            ?? components.queryItems?.first(where: { $0.name == "title" })?.value

        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
              let router = appDelegate.container.resolve(AppRouter.self),
              let articlesManager = appDelegate.container.resolve(ArticlesManagerProtocol.self) else { return }

        // Match against cached articles first, or fetch asynchronously
        if let articles = articlesManager.cachedArticles()?.articles {
            if let match = findMatchingArticle(in: articles, target: targetParam) {
                router.showArticleDetail(for: match)
                return
            }
        }

        Task { @MainActor in
            let result = await articlesManager.loadArticles()
            if let match = self.findMatchingArticle(in: result.articles, target: targetParam) {
                router.showArticleDetail(for: match)
            }
        }
    }

    private func findMatchingArticle(in articles: [Article], target: String?) -> Article? {
        guard let target, !target.isEmpty else { return articles.first }
        return articles.first(where: { article in
            article.url == target ||
            article.title == target ||
            (article.title?.localizedCaseInsensitiveContains(target) ?? false)
        })
    }
}
