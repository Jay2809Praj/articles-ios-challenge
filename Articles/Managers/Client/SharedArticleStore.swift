import CryptoKit
import Foundation

/// What the widget knows about one article. Written by the app, read by the
/// widget extension; it deliberately carries no logic of its own.
struct WidgetArticleData: Codable, Equatable {
    /// `Article.identifier`, so a deep link can open exactly this article.
    let id: String
    let title: String
    let sourceName: String?
    let dateString: String?
    let webURL: String?
    let imageURL: String?
    /// `true` when the user saved the article for later.
    let isSaved: Bool

    init(
        id: String,
        title: String,
        sourceName: String? = nil,
        dateString: String? = nil,
        webURL: String? = nil,
        imageURL: String? = nil,
        isSaved: Bool = false
    ) {
        self.id = id
        self.title = title
        self.sourceName = sourceName
        self.dateString = dateString
        self.webURL = webURL
        self.imageURL = imageURL
        self.isSaved = isSaved
    }
}

/// The hand-off point between the app and the widget: a folder inside the
/// App Group container holding the article list, one downsampled image per
/// article and the index the user has browsed to with the widget's buttons.
///
/// The app is the only writer of articles and images; the widget only reads
/// them and moves the index. Nothing here talks to the network and nothing
/// here knows about WidgetKit, so the same code is compiled into both targets.
final class SharedArticleStore {
    static let appGroupID = "group.com.jayprajapati.Articles"

    /// The store backed by the App Group container. `isAvailable` is `false`
    /// when the entitlement is missing, and every call then becomes a no-op.
    static let shared = SharedArticleStore(
        containerURL: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    )

    private struct State: Codable {
        var currentIndex: Int
    }

    private let directoryURL: URL?
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// - Parameter containerURL: the shared container, or any directory in tests.
    init(containerURL: URL?, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        directoryURL = containerURL?.appendingPathComponent("WidgetContent", isDirectory: true)
    }

    var isAvailable: Bool { directoryURL != nil }

    // MARK: - Articles

    /// Replaces the list the widget shows. Images of articles that are no
    /// longer listed are deleted so the folder never grows beyond the list.
    func saveArticles(_ articles: [WidgetArticleData]) {
        guard let directoryURL, let data = try? encoder.encode(articles) else { return }
        ensureDirectoryExists()
        try? data.write(to: directoryURL.appendingPathComponent(Self.articlesFileName), options: .atomic)
        pruneImages(keeping: Set(articles.map(\.id)))
        clampIndex(to: articles.count)
    }

    func loadArticles() -> [WidgetArticleData] {
        guard let directoryURL,
              let data = try? Data(contentsOf: directoryURL.appendingPathComponent(Self.articlesFileName)),
              let articles = try? decoder.decode([WidgetArticleData].self, from: data)
        else {
            return []
        }
        return articles
    }

    /// The article the widget is currently showing, with its position.
    func currentArticle() -> (article: WidgetArticleData, index: Int, total: Int)? {
        let articles = loadArticles()
        guard !articles.isEmpty else { return nil }
        let index = min(max(currentIndex(), 0), articles.count - 1)
        return (articles[index], index, articles.count)
    }

    // MARK: - Browsing (driven by the widget's buttons)

    func currentIndex() -> Int {
        guard let directoryURL,
              let data = try? Data(contentsOf: directoryURL.appendingPathComponent(Self.stateFileName)),
              let state = try? decoder.decode(State.self, from: data)
        else {
            return 0
        }
        return state.currentIndex
    }

    func cycleToNextArticle() {
        let count = loadArticles().count
        guard count > 0 else { return }
        setCurrentIndex((currentIndex() + 1) % count)
    }

    func cycleToPreviousArticle() {
        let count = loadArticles().count
        guard count > 0 else { return }
        setCurrentIndex((currentIndex() - 1 + count) % count)
    }

    // MARK: - Images

    func hasImage(for articleID: String) -> Bool {
        guard let url = imageFileURL(for: articleID) else { return false }
        return fileManager.fileExists(atPath: url.path)
    }

    func saveImageData(_ data: Data, for articleID: String) {
        guard !data.isEmpty, let url = imageFileURL(for: articleID) else { return }
        ensureDirectoryExists()
        try? data.write(to: url, options: .atomic)
    }

    func loadImageData(for articleID: String) -> Data? {
        guard let url = imageFileURL(for: articleID),
              let data = try? Data(contentsOf: url), !data.isEmpty
        else {
            return nil
        }
        return data
    }

    /// Removes everything the store holds.
    func clear() {
        guard let directoryURL else { return }
        try? fileManager.removeItem(at: directoryURL)
    }

    // MARK: - Private

    private static let articlesFileName = "articles.json"
    private static let stateFileName = "state.json"
    private static let imagesDirectoryName = "Images"

    private var imagesDirectoryURL: URL? {
        directoryURL?.appendingPathComponent(Self.imagesDirectoryName, isDirectory: true)
    }

    private func imageFileURL(for articleID: String) -> URL? {
        imagesDirectoryURL?.appendingPathComponent(Self.fileName(for: articleID))
    }

    /// Identifiers contain URLs; a hash makes a safe, fixed-length file name.
    private static func fileName(for articleID: String) -> String {
        let digest = SHA256.hash(data: Data(articleID.utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".jpg"
    }

    private func ensureDirectoryExists() {
        guard let imagesDirectoryURL else { return }
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true)
    }

    private func pruneImages(keeping articleIDs: Set<String>) {
        guard let imagesDirectoryURL,
              let files = try? fileManager.contentsOfDirectory(at: imagesDirectoryURL, includingPropertiesForKeys: nil)
        else {
            return
        }
        let wanted = Set(articleIDs.map(Self.fileName(for:)))
        for file in files where !wanted.contains(file.lastPathComponent) {
            try? fileManager.removeItem(at: file)
        }
    }

    private func setCurrentIndex(_ index: Int) {
        guard let directoryURL, let data = try? encoder.encode(State(currentIndex: index)) else { return }
        ensureDirectoryExists()
        try? data.write(to: directoryURL.appendingPathComponent(Self.stateFileName), options: .atomic)
    }

    private func clampIndex(to count: Int) {
        let index = currentIndex()
        if count == 0 {
            setCurrentIndex(0)
        } else if index < 0 || index >= count {
            setCurrentIndex(0)
        }
    }
}
