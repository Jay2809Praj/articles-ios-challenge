import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Lightweight transfer model representing an article for WidgetKit.
public struct WidgetArticleData: Codable, Equatable {
    public let title: String
    public let sourceName: String?
    public let dateString: String?
    public let webURL: String?
    public let imageURL: String?
    public let imageData: Data?

    public init(
        title: String,
        sourceName: String? = nil,
        dateString: String? = nil,
        webURL: String? = nil,
        imageURL: String? = nil,
        imageData: Data? = nil
    ) {
        self.title = title
        self.sourceName = sourceName
        self.dateString = dateString
        self.webURL = webURL
        self.imageURL = imageURL
        self.imageData = imageData
    }
}

/// Shared storage bridge between the main Articles app and the ArticlesWidget extension.
public enum SharedArticleStore {
    public static let appGroupID = "group.com.jayprajapati.Articles"
    public static let storageKey = "latest_article_widget_data"
    public static let articlesListKey = "latest_articles_list"
    public static let currentIndexKey = "latest_article_current_index"
    public static let sharedFileName = "articles_list.json"
    public static let sharedLegacyFileName = "latest_article.json"
    public static let sharedImageFileName = "latest_article_image.jpg"
    public static let imageStorageKey = "latest_article_image_data"

    /// Real API endpoint used across the Articles app.
    public static let realAPIEndpoint = "https://mocki.io/v1/9f09ed09-d8ca-48c7-9957-dec39e745321"

    private static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Shared directory path that works across app and extension.
    private static var sharedDirectoryURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    private static var sharedFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(sharedFileName)
    }

    private static var sharedLegacyFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(sharedLegacyFileName)
    }

    private static var sharedImageFileURL: URL? {
        sharedDirectoryURL?.appendingPathComponent(sharedImageFileName)
    }

    // MARK: - Multiple Articles Support

    public static func saveArticles(_ articles: [WidgetArticleData]) {
        guard !articles.isEmpty else { return }
        guard let encoded = try? JSONEncoder().encode(articles) else { return }
        userDefaults.set(encoded, forKey: articlesListKey)

        if let fileURL = sharedFileURL {
            try? encoded.write(to: fileURL, options: .atomic)
        }

        // Also save first article for legacy single-item consumers
        if let first = articles.first {
            save(first)
        }

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func loadArticles() -> [WidgetArticleData] {
        if let fileURL = sharedFileURL,
           let fileData = try? Data(contentsOf: fileURL),
           let list = try? JSONDecoder().decode([WidgetArticleData].self, from: fileData),
           !list.isEmpty {
            return list
        }

        if let data = userDefaults.data(forKey: articlesListKey),
           let list = try? JSONDecoder().decode([WidgetArticleData].self, from: data),
           !list.isEmpty {
            return list
        }

        if let single = loadLatestArticle() {
            return [single]
        }

        return defaultRealArticles
    }

    /// Real curated articles directly from the app API for instant presentation.
    public static let defaultRealArticles: [WidgetArticleData] = [
        WidgetArticleData(
            title: "Dogecoin Payments On X: Cardano Founder Offers Elon Musk Bitcoin Roadmap For Implementation",
            sourceName: "Bitcoinist",
            dateString: "Today",
            webURL: "https://bitcoinist.com/dogecoin-payments-on-x-cardano-elon-musk/",
            imageURL: "https://bitcoinist.com/wp-content/uploads/2025/03/dogecoin-payments-x-cardano-elon-musk.jpg"
        ),
        WidgetArticleData(
            title: "Trump Tightens Leash on Elon Musk and DOGE: It’s Time for ‘Scalpel Rather Than Hatchet’",
            sourceName: "Mediaite",
            dateString: "Today",
            webURL: "https://www.mediaite.com/trump/trump-tightens-leash-on-elon-musk-and-doge-its-time-for-scalpel-rather-than-hatchet/",
            imageURL: "https://www.mediaite.com/wp-content/uploads/2025/02/AP25042756828063-scaled.jpg"
        ),
        WidgetArticleData(
            title: "Tesla stock sinks 6% after Baird analysts say Musk's government role adds 'uncertainty' to delivery outlook",
            sourceName: "Biztoc.com",
            dateString: "Today",
            webURL: "https://biztoc.com/x/95a955058a1fe5c9",
            imageURL: "https://biztoc.com/cdn/906/og.png"
        ),
        WidgetArticleData(
            title: "Baki Hanma Reveals New Video Game (And It’s Coming To America)",
            sourceName: "ComicBook.com",
            dateString: "Today",
            webURL: "http://comicbook.com/anime/news/baki-hanma-new-game-north-america/",
            imageURL: "https://comicbook.com/wp-content/uploads/sites/4/2025/03/Baki-Hanma.jpg?w=1920"
        ),
        WidgetArticleData(
            title: "House panel subpoenas Google parent Alphabet over content moderation during Biden years",
            sourceName: "New York Post",
            dateString: "Today",
            webURL: "https://nypost.com/2025/03/06/business/house-panel-subpoenas-google-parent-alphabet-over-content-moderation/",
            imageURL: "https://nypost.com/wp-content/uploads/sites/2/2025/03/newspress-collage-lscpqkxqs-1741289761373.jpg?quality=75&strip=all&1741271795&w=1024"
        )
    ]

    // MARK: - Interactive Widget Navigation

    public static func getCurrentIndex() -> Int {
        userDefaults.integer(forKey: currentIndexKey)
    }

    public static func cycleToNextArticle() {
        let articles = loadArticles()
        guard !articles.isEmpty else { return }
        let nextIndex = (getCurrentIndex() + 1) % articles.count
        userDefaults.set(nextIndex, forKey: currentIndexKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func cycleToPreviousArticle() {
        let articles = loadArticles()
        guard !articles.isEmpty else { return }
        let prevIndex = (getCurrentIndex() - 1 + articles.count) % articles.count
        userDefaults.set(prevIndex, forKey: currentIndexKey)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func currentArticle() -> (article: WidgetArticleData, index: Int, total: Int)? {
        let list = loadArticles()
        guard !list.isEmpty else { return nil }
        var index = getCurrentIndex()
        if index < 0 || index >= list.count {
            index = 0
            userDefaults.set(0, forKey: currentIndexKey)
        }
        return (list[index], index, list.count)
    }

    // MARK: - Single Article Backward Compatibility

    public static func saveLatestArticle(
        title: String,
        sourceName: String? = nil,
        dateString: String? = nil,
        webURL: String? = nil,
        imageURL: String? = nil,
        imageData: Data? = nil
    ) {
        let data = WidgetArticleData(
            title: title,
            sourceName: sourceName,
            dateString: dateString,
            webURL: webURL,
            imageURL: imageURL,
            imageData: imageData
        )
        save(data)
    }

    public static func save(_ data: WidgetArticleData) {
        guard let encoded = try? JSONEncoder().encode(data) else { return }
        userDefaults.set(encoded, forKey: storageKey)

        if let fileURL = sharedLegacyFileURL {
            try? encoded.write(to: fileURL, options: .atomic)
        }

        if let imageData = data.imageData {
            saveImageData(imageData, forIndex: 0)
        } else {
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    public static func loadLatestArticle() -> WidgetArticleData? {
        if let fileURL = sharedLegacyFileURL,
           let fileData = try? Data(contentsOf: fileURL),
           let article = try? JSONDecoder().decode(WidgetArticleData.self, from: fileData) {
            return article
        }

        if let defaultsData = userDefaults.data(forKey: storageKey),
           let article = try? JSONDecoder().decode(WidgetArticleData.self, from: defaultsData) {
            return article
        }

        return nil
    }

    // MARK: - Image Data Storage (Per-Index & Global)

    public static func saveImageData(_ data: Data, forIndex index: Int = 0) {
        let filename = "latest_article_image_\(index).jpg"
        if let fileURL = sharedDirectoryURL?.appendingPathComponent(filename) {
            try? data.write(to: fileURL, options: .atomic)
        }
        if index == 0 {
            if let defaultURL = sharedImageFileURL {
                try? data.write(to: defaultURL, options: .atomic)
            }
        }
        userDefaults.set(data, forKey: "\(imageStorageKey)_\(index)")
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    public static func loadImageData(forIndex index: Int = 0) -> Data? {
        let filename = "latest_article_image_\(index).jpg"
        if let fileURL = sharedDirectoryURL?.appendingPathComponent(filename),
           let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            return data
        }
        if let data = userDefaults.data(forKey: "\(imageStorageKey)_\(index)"), !data.isEmpty {
            return data
        }
        if let defaultURL = sharedImageFileURL,
           let data = try? Data(contentsOf: defaultURL), !data.isEmpty {
            return data
        }
        return userDefaults.data(forKey: imageStorageKey)
    }
}
