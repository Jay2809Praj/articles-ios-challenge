import Swinject
import UIKit

/// Creates the storyboard-backed view controllers with their dependencies.
protocol ViewControllerFactoryProtocol {
    func makeArticleList(router: ArticleRouting) -> ArticleListViewController
    func makeArticleDetail(for article: Article, router: ArticleRouting) -> ArticleDetailViewController
}

/// Instantiates view controllers from their storyboards and injects managers
/// resolved from the Swinject container through the initialiser, so a view
/// controller can never exist without what it needs.
final class ViewControllerFactory: ViewControllerFactoryProtocol {
    private let resolver: Resolver

    init(resolver: Resolver) {
        self.resolver = resolver
    }

    func makeArticleList(router: ArticleRouting) -> ArticleListViewController {
        let resolver = resolver
        return UIStoryboard(name: AppConstants.Storyboard.articleList, bundle: .main)
            .instantiateViewController(identifier: "ArticleListViewController") { coder in
                ArticleListViewController(
                    coder: coder,
                    articlesManager: resolver.resolve(ArticlesManagerProtocol.self)!,
                    connectivityManager: resolver.resolve(ConnectivityManagerProtocol.self)!,
                    router: router
                )
            }
    }

    func makeArticleDetail(for article: Article, router: ArticleRouting) -> ArticleDetailViewController {
        let resolver = resolver
        return UIStoryboard(name: AppConstants.Storyboard.articleDetail, bundle: .main)
            .instantiateViewController(identifier: "ArticleDetailViewController") { coder in
                ArticleDetailViewController(
                    coder: coder,
                    article: article,
                    favoritesManager: resolver.resolve(FavoritesManagerProtocol.self)!,
                    router: router
                )
            }
    }
}
