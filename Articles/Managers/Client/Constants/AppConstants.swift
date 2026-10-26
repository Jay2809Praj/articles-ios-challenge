import CoreGraphics
import Foundation

/// Non-visual constants.
enum AppConstants {
    enum Network {
        static let requestTimeout: TimeInterval = 15
        static let resourceTimeout: TimeInterval = 30
    }

    enum Cache {
        static let storageName = "ArticlesCache"
        static let articlesKey = "articles.latest"
    }

    enum Favorites {
        static let storageKey = "favorites.identifiers"
    }

    enum SavedArticles {
        static let storageName = "SavedArticlesCache"
        static let recordsKey = "saved_articles.records"
        static let maxStorageBytes: Int64 = 50 * 1024 * 1024 // 50 MB limit
        /// Under Application Support: the images of saved articles.
        static let imagesDirectory = "SavedArticles/Images"
        static let didChangeNotification = Notification.Name("SavedArticlesDidChangeNotification")
    }

    enum Widget {
        static let lastOpenedArticleKey = "widget.lastOpenedArticle"
    }

    enum Pagination {
        /// Articles per page, as the (simulated) server would hand them out.
        static let pageSize = 10
        /// How long the provider takes to answer a page it already holds.
        static let simulatedLatency: TimeInterval = 0.6
    }

    enum Storyboard {
        static let articleList = "ArticleList"
        static let articleDetail = "ArticleDetail"
    }
}
