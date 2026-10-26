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
        static let didChangeNotification = Notification.Name("SavedArticlesDidChangeNotification")
    }

    enum Widget {
        static let lastOpenedArticleKey = "widget.lastOpenedArticle"
    }

    enum Pagination {
        static let pageSize = 10
        static let simulatedLoadDelay: TimeInterval = 0.8
    }

    enum Storyboard {
        static let articleList = "ArticleList"
        static let articleDetail = "ArticleDetail"
    }
}
