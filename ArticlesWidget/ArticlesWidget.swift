import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents (Interactive Widget Controls)

struct NextArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Article"
    static var description = IntentDescription("Displays the next article in the Articles widget.")

    func perform() async throws -> some IntentResult {
        SharedArticleStore.cycleToNextArticle()
        return .result()
    }
}

struct PreviousArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Article"
    static var description = IntentDescription("Displays the previous article in the Articles widget.")

    func perform() async throws -> some IntentResult {
        SharedArticleStore.cycleToPreviousArticle()
        return .result()
    }
}

// MARK: - Timeline Entry

/// Timeline entry holding article data, current index, and photo for presentation.
struct ArticleWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let sourceName: String
    let dateString: String
    let webURL: String?
    let imageURL: String?
    let imageData: Data?
    let currentIndex: Int
    let totalArticles: Int
}

// MARK: - Provider

/// Provider managing instant timeline updates with zero skeleton delay.
struct ArticlesWidgetProvider: TimelineProvider {
    private var defaultEntry: ArticleWidgetEntry {
        let first = SharedArticleStore.defaultRealArticles[0]
        return ArticleWidgetEntry(
            date: Date(),
            title: first.title,
            sourceName: first.sourceName ?? "Bitcoinist",
            dateString: "Today",
            webURL: first.webURL,
            imageURL: first.imageURL,
            imageData: nil,
            currentIndex: 0,
            totalArticles: SharedArticleStore.defaultRealArticles.count
        )
    }

    func placeholder(in context: Context) -> ArticleWidgetEntry {
        defaultEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (ArticleWidgetEntry) -> Void) {
        let current = SharedArticleStore.currentArticle() ?? (
            article: SharedArticleStore.defaultRealArticles[0],
            index: 0,
            total: SharedArticleStore.defaultRealArticles.count
        )
        let cachedImageData = SharedArticleStore.loadImageData(forIndex: current.index)
        let entry = ArticleWidgetEntry(
            date: Date(),
            title: current.article.title,
            sourceName: current.article.sourceName ?? "Articles",
            dateString: current.article.dateString ?? "Recent",
            webURL: current.article.webURL,
            imageURL: current.article.imageURL,
            imageData: cachedImageData,
            currentIndex: current.index,
            totalArticles: current.total
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArticleWidgetEntry>) -> Void) {
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()

        // 1. Fetch current article synchronously (GUARANTEED immediate, never blocks or hangs)
        let current = SharedArticleStore.currentArticle() ?? (
            article: SharedArticleStore.defaultRealArticles[0],
            index: 0,
            total: SharedArticleStore.defaultRealArticles.count
        )

        let index = current.index
        let cachedImageData = SharedArticleStore.loadImageData(forIndex: index)

        let entry = ArticleWidgetEntry(
            date: Date(),
            title: current.article.title,
            sourceName: current.article.sourceName ?? "Articles",
            dateString: current.article.dateString ?? "Recent",
            webURL: current.article.webURL,
            imageURL: current.article.imageURL,
            imageData: cachedImageData,
            currentIndex: index,
            totalArticles: current.total
        )

        // Return immediately so SpringBoard renders the full widget content without skeleton delay
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))

        // 2. Asynchronously download image for this index if missing
        if cachedImageData == nil, let imageURL = current.article.imageURL {
            fetchImageData(from: imageURL) { downloadedData in
                guard let downloadedData else { return }
                SharedArticleStore.saveImageData(downloadedData, forIndex: index)
            }
        }

        // 3. Asynchronously refresh latest articles from real API
        refreshFromRealAPIInBackground()
    }

    private func fetchImageData(from urlString: String?, completion: @escaping (Data?) -> Void) {
        guard let urlString, let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            completion(data)
        }.resume()
    }

    private func refreshFromRealAPIInBackground() {
        guard let url = URL(string: SharedArticleStore.realAPIEndpoint) else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data else { return }

            struct Response: Decodable {
                struct RawArticle: Decodable {
                    let title: String?
                    let url: String?
                    let urlToImage: String?
                    let publishedAt: String?
                    let source: RawSource?
                }
                struct RawSource: Decodable {
                    let name: String?
                }
                let articles: [RawArticle]?
            }

            guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
                  let rawArticles = decoded.articles, !rawArticles.isEmpty else { return }

            let validArticles = rawArticles.compactMap { raw -> WidgetArticleData? in
                guard let title = raw.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
                return WidgetArticleData(
                    title: title,
                    sourceName: raw.source?.name ?? "News",
                    dateString: "Recent",
                    webURL: raw.url,
                    imageURL: raw.urlToImage
                )
            }

            guard !validArticles.isEmpty else { return }
            SharedArticleStore.saveArticles(validArticles)

            // Prefetch image for current article
            let currentIndex = SharedArticleStore.getCurrentIndex()
            if currentIndex < validArticles.count,
               let imageURL = validArticles[currentIndex].imageURL {
                self.fetchImageData(from: imageURL) { downloadedData in
                    guard let downloadedData else { return }
                    SharedArticleStore.saveImageData(downloadedData, forIndex: currentIndex)
                }
            }
        }.resume()
    }
}

// MARK: - SwiftUI Widget Entry View

/// SwiftUI widget view supporting interactive browsing, real API data, and magazine-grade photos.
struct ArticlesWidgetEntryView: View {
    var entry: ArticlesWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    private let themeBlue = Color(red: 25.0 / 255.0, green: 90.0 / 255.0, blue: 148.0 / 255.0)

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallContent
            case .systemLarge:
                largeContent
            default:
                mediumContent
            }
        }
        .unredacted()
        .widgetURL(deepLinkURL)
        .containerBackground(for: .widget) {
            containerBackgroundView
        }
    }

    private var deepLinkURL: URL? {
        guard let webURL = entry.webURL else {
            return URL(string: "articles://open")
        }
        var components = URLComponents()
        components.scheme = "articles"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "url", value: webURL)]
        return components.url
    }

    @ViewBuilder
    private var containerBackgroundView: some View {
        if family == .systemSmall {
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2),
                                Color.black.opacity(0.55),
                                Color.black.opacity(0.95)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            } else {
                LinearGradient(
                    colors: [themeBlue, Color(red: 10 / 255, green: 30 / 255, blue: 60 / 255)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } else {
            Color(.secondarySystemGroupedBackground)
        }
    }

    // MARK: - Medium Layout (Interactive Magazine Split)

    private var mediumContent: some View {
        HStack(spacing: 12) {
            imageThumbnailView(width: 112)

            VStack(alignment: .leading, spacing: 5) {
                // Header with Source, Counter, and Interactive Buttons
                HStack(spacing: 5) {
                    Circle()
                        .fill(themeBlue)
                        .frame(width: 6, height: 6)

                    Text(entry.sourceName.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(themeBlue)
                        .lineLimit(1)

                    Spacer()

                    // Index indicator e.g. 1/5
                    Text("\(entry.currentIndex + 1)/\(max(entry.totalArticles, 1))")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())

                    // Interactive Prev & Next buttons right on the widget
                    HStack(spacing: 3) {
                        Button(intent: PreviousArticleIntent()) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(themeBlue)
                        }
                        .buttonStyle(.plain)

                        Button(intent: NextArticleIntent()) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(themeBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(entry.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)

                Spacer(minLength: 0)

                // Footer with Date and Read Action
                HStack {
                    Label(entry.dateString, systemImage: "clock")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Link(destination: deepLinkURL ?? URL(string: "articles://open")!) {
                        HStack(spacing: 3) {
                            Text("Read")
                                .font(.system(size: 11, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(themeBlue, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Small Layout (Interactive Cover)

    private var smallContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.sourceName.uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.white.opacity(0.22), in: Capsule())

                Spacer()

                // Interactive Next Button
                Button(intent: NextArticleIntent()) {
                    HStack(spacing: 2) {
                        Text("\(entry.currentIndex + 1)")
                            .font(.system(size: 8, weight: .bold))
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.4), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text(entry.title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)

            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(entry.dateString)
                        .font(.system(size: 9, weight: .medium))
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Large Layout (Hero Magazine Card)

    private var largeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [themeBlue, themeBlue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "newspaper.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeBlue)
                        .frame(width: 6, height: 6)
                    Text(entry.sourceName.uppercased())
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(themeBlue)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(entry.dateString)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(entry.currentIndex + 1) of \(max(entry.totalArticles, 1))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Button(intent: PreviousArticleIntent()) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(themeBlue)
                        }
                        .buttonStyle(.plain)

                        Button(intent: NextArticleIntent()) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(themeBlue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(entry.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack {
                    Text("Tap to read full article")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Link(destination: deepLinkURL ?? URL(string: "articles://open")!) {
                        HStack(spacing: 4) {
                            Text("Open Story")
                                .font(.system(size: 12, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeBlue, in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Reusable Image Thumbnail

    @ViewBuilder
    private func imageThumbnailView(width: CGFloat) -> some View {
        if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: width)
                .frame(maxHeight: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        } else {
            ZStack {
                LinearGradient(
                    colors: [themeBlue, themeBlue.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                VStack(spacing: 6) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(entry.sourceName)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Widget Configuration

/// The Widget definition exported by the extension.
struct ArticlesWidget: Widget {
    let kind: String = "ArticlesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ArticlesWidgetProvider()) { entry in
            ArticlesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Latest Articles")
        .description("Browse real news articles with photos and switch stories directly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
