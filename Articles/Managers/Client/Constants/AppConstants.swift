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

    enum Storyboard {
        static let articleList = "ArticleList"
        static let articleDetail = "ArticleDetail"
    }
}
