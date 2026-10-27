import AppIntents
import SwiftUI
import WidgetKit

// MARK: - App Intents (the widget's Previous / Next buttons)

struct NextArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Article"
    static var description = IntentDescription("Shows the next article in the Articles widget.")

    func perform() async throws -> some IntentResult {
        SharedArticleStore.shared.cycleToNextArticle()
        WidgetCenter.shared.reloadTimelines(ofKind: ArticlesWidget.kind)
        return .result()
    }
}

struct PreviousArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Article"
    static var description = IntentDescription("Shows the previous article in the Articles widget.")

    func perform() async throws -> some IntentResult {
        SharedArticleStore.shared.cycleToPreviousArticle()
        WidgetCenter.shared.reloadTimelines(ofKind: ArticlesWidget.kind)
        return .result()
    }
}

// MARK: - Timeline Entry

/// One article from the app, or nothing when the app has not loaded any yet.
struct ArticleWidgetEntry: TimelineEntry {
    let date: Date
    let article: WidgetArticleData?
    let imageData: Data?
    let index: Int
    let total: Int

    static let empty = ArticleWidgetEntry(date: Date(), article: nil, imageData: nil, index: 0, total: 0)

    /// Skeleton for the widget gallery, rendered redacted. It is layout
    /// filler, not content: real entries only ever come from the app's store.
    static let placeholder = ArticleWidgetEntry(
        date: Date(),
        article: WidgetArticleData(id: "placeholder", title: "Article headline", sourceName: "Source", dateString: "Today"),
        imageData: nil,
        index: 0,
        total: 1
    )
}

// MARK: - Provider

/// Reads whatever the app last published. No networking happens here: the app
/// owns the data and asks WidgetKit to reload whenever it changes.
struct ArticlesWidgetProvider: TimelineProvider {
    private let store = SharedArticleStore.shared

    func placeholder(in context: Context) -> ArticleWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ArticleWidgetEntry) -> Void) {
        completion(context.isPreview && currentEntry().article == nil ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ArticleWidgetEntry>) -> Void) {
        // The app triggers reloads; the hourly refresh only guards against a missed one.
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [currentEntry()], policy: .after(refresh)))
    }

    private func currentEntry() -> ArticleWidgetEntry {
        guard let current = store.currentArticle() else { return .empty }
        return ArticleWidgetEntry(
            date: Date(),
            article: current.article,
            imageData: store.loadImageData(for: current.article.id),
            index: current.index,
            total: current.total
        )
    }
}

// MARK: - Entry View

struct ArticlesWidgetEntryView: View {
    var entry: ArticlesWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons

    private let themeBlue = Color(red: 25.0 / 255.0, green: 90.0 / 255.0, blue: 148.0 / 255.0)

    var body: some View {
        Group {
            if let article = entry.article {
                articleContent(article)
            } else {
                emptyContent
            }
        }
        .widgetURL(deepLinkURL)
        .containerBackground(for: .widget) {
            containerBackgroundView
        }
    }

    @ViewBuilder
    private func articleContent(_ article: WidgetArticleData) -> some View {
        switch family {
        case .systemSmall:
            smallContent(article)
        case .systemLarge:
            largeContent(article)
        default:
            mediumContent(article)
        }
    }

    /// Opens the exact article in the app, or just the app when there is none.
    private var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "articles"
        components.host = "open"
        if let article = entry.article, !isPlaceholder {
            components.queryItems = [URLQueryItem(name: "id", value: article.id)]
        }
        return components.url
    }

    private var isPlaceholder: Bool {
        redactionReasons.contains(.placeholder)
    }

    private var image: UIImage? {
        entry.imageData.flatMap(UIImage.init(data:))
    }

    @ViewBuilder
    private var containerBackgroundView: some View {
        if family == .systemSmall, entry.article != nil {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.2), Color.black.opacity(0.55), Color.black.opacity(0.95)],
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

    // MARK: Empty state

    private var emptyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "newspaper")
                .font(.system(size: family == .systemSmall ? 26 : 34, weight: .medium))
                .foregroundColor(themeBlue)
            Text("No articles yet")
                .font(.system(size: family == .systemSmall ? 13 : 15, weight: .bold))
                .foregroundColor(.primary)
            Text("Open Articles to load the latest news.")
                .font(.system(size: family == .systemSmall ? 10 : 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Shared pieces

    private var positionText: String {
        "\(entry.index + 1)/\(max(entry.total, 1))"
    }

    private func sourceLabel(_ article: WidgetArticleData, size: CGFloat) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(themeBlue)
                .frame(width: 6, height: 6)
            Text((article.sourceName ?? "Articles").uppercased())
                .font(.system(size: size, weight: .bold))
                .foregroundColor(themeBlue)
                .lineLimit(1)
            if article.isSaved {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: size, weight: .bold))
                    .foregroundColor(themeBlue)
                    .accessibilityLabel("Saved")
            }
        }
    }

    private func browseButtons(size: CGFloat) -> some View {
        HStack(spacing: 3) {
            Button(intent: PreviousArticleIntent()) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(themeBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous article")

            Button(intent: NextArticleIntent()) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: size))
                    .foregroundColor(themeBlue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next article")
        }
    }

    private func readLink(title: String, fontSize: CGFloat) -> some View {
        Link(destination: deepLinkURL ?? URL(string: "articles://open")!) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: fontSize, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: fontSize - 1, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(themeBlue, in: Capsule())
        }
    }

    // MARK: Medium

    private func mediumContent(_ article: WidgetArticleData) -> some View {
        HStack(spacing: 12) {
            thumbnail(article, width: 112)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    sourceLabel(article, size: 10)
                    Spacer()
                    Text(positionText)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                    browseButtons(size: 16)
                }

                Text(article.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)

                Spacer(minLength: 0)

                HStack {
                    Label(article.dateString ?? "Recent", systemImage: "clock")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    readLink(title: "Read", fontSize: 11)
                }
            }
        }
    }

    // MARK: Small

    private func smallContent(_ article: WidgetArticleData) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 3) {
                    Text((article.sourceName ?? "Articles").uppercased())
                    if article.isSaved {
                        Image(systemName: "bookmark.fill")
                    }
                }
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.22), in: Capsule())
                .lineLimit(1)

                Spacer()

                Button(intent: NextArticleIntent()) {
                    HStack(spacing: 2) {
                        Text(positionText)
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
                .accessibilityLabel("Next article")
            }

            Spacer()

            Text(article.title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .shadow(color: .black.opacity(0.7), radius: 3, x: 0, y: 1)

            HStack {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(article.dateString ?? "Recent")
                        .font(.system(size: 9, weight: .medium))
                }
                Spacer()
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 10))
            }
            .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: Large

    private func largeContent(_ article: WidgetArticleData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipped()
                } else {
                    imageFallback(sourceName: nil, iconSize: 40)
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
                    sourceLabel(article, size: 11)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(article.dateString ?? "Recent")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(entry.index + 1) of \(max(entry.total, 1))")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    browseButtons(size: 18)
                }

                Text(article.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                HStack {
                    Text("Tap to read the full article")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    readLink(title: "Open Story", fontSize: 12)
                }
            }
        }
    }

    // MARK: Thumbnail

    @ViewBuilder
    private func thumbnail(_ article: WidgetArticleData, width: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
                    .clipped()
            } else {
                imageFallback(sourceName: article.sourceName, iconSize: 26)
                    .frame(width: width)
                    .frame(maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func imageFallback(sourceName: String?, iconSize: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [themeBlue, themeBlue.opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 6) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                if let sourceName {
                    Text(sourceName)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                }
            }
        }
    }
}

// MARK: - Widget Configuration

struct ArticlesWidget: Widget {
    static let kind = "ArticlesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ArticlesWidgetProvider()) { entry in
            ArticlesWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Latest Articles")
        .description("Browse the articles loaded and saved in the app, right from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
