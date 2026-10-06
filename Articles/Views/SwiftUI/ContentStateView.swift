import SwiftUI

/// Full-area placeholder for everything that is not "a list of articles":
/// loading, offline, errors, empty results and the iPad's empty detail pane.
///
/// Built in SwiftUI and embedded in UIKit through `ContentStateViewController`.
/// The offline variant follows the Figma "You're offline" frame; the others
/// reuse its layout with their own icon and copy.
struct ContentStateView: View {
    enum Kind: Equatable {
        case loading
        case offline
        case error(message: String)
        case empty
        case noResults(query: String)
        case selectArticle
    }

    let kind: Kind
    var onRetry: (() -> Void)?

    // Reading the size keeps the UIFontMetrics-scaled fonts below in step
    // with the user's Dynamic Type setting.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            if kind == .loading {
                ArticleSkeletonList()
            } else {
                message
            }
        }
        .animation(.easeInOut(duration: 0.25), value: kind)
    }

    private var message: some View {
        VStack(spacing: 23) {
            icon
                .accessibilityHidden(true)

            Text(title)
                .font(Font(AppFont.stateTitle))
                .foregroundStyle(Color.black)

            Text(detail)
                .font(Font(AppFont.stateMessage))
                .foregroundStyle(Color(uiColor: AppColor.offlineMessage))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if showsRetry, let onRetry {
                RetryButton(action: onRetry)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    @ViewBuilder
    private var icon: some View {
        switch kind {
        case .offline:
            Image(AppIcon.Name.offline)
                .resizable()
                .frame(width: 78, height: 62)
        default:
            Image(systemName: symbolName)
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(Color(uiColor: AppColor.offlineIcon))
                .frame(height: 62)
        }
    }

    private var background: Color {
        switch kind {
        case .loading: Color(uiColor: AppColor.background)
        case .selectArticle: Color(uiColor: AppColor.detailBackground)
        default: Color(uiColor: AppColor.offlineBackground)
        }
    }

    private var symbolName: String {
        switch kind {
        case .error: AppIcon.Name.error
        case .noResults: AppIcon.Name.noResults
        case .selectArticle: AppIcon.Name.selectArticle
        default: AppIcon.Name.empty
        }
    }

    private var title: String {
        switch kind {
        case .loading: ""
        case .offline: "You’re offline"
        case .error: "Something went wrong"
        case .empty: "No articles yet"
        case .noResults: "No results"
        case .selectArticle: "Select an article"
        }
    }

    private var detail: String {
        switch kind {
        case .loading: ""
        case .offline: "Please connect to the internet and try again."
        case .error(let message): message
        case .empty: "There is nothing to read right now. Please check back later."
        case .noResults(let query): "Nothing matches “\(query)”."
        case .selectArticle: "Choose an article from the list to read it here."
        }
    }

    private var showsRetry: Bool {
        switch kind {
        case .offline, .error, .empty: true
        default: false
        }
    }
}

// MARK: - Retry button

/// The "Retry" pill from the design, with a press animation and a spinning
/// arrow as feedback that the tap was registered.
private struct RetryButton: View {
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var rotation = 0.0

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.6)) { rotation -= 360 }
            action()
        } label: {
            HStack(spacing: 12) {
                Image(AppIcon.Name.retry)
                    .resizable()
                    .frame(width: 16, height: 18)
                    .rotationEffect(.degrees(rotation))
                Text("Retry")
                    .font(Font(AppFont.stateButton))
                    .foregroundStyle(Color.black)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color(uiColor: AppColor.retryBackground), in: Capsule())
            .shadow(color: .black.opacity(0.25), radius: 1)
            // The visible pill is 26 pt tall; keep a comfortable touch target.
            .padding(9)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .padding(-9)
        .accessibilityHint("Loads the articles again")
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Loading skeleton

/// Placeholder cards with the proportions of the real ones, shown while the
/// first page loads so the layout does not jump when content arrives.
private struct ArticleSkeletonList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    var body: some View {
        VStack(spacing: AppMetrics.List.cardSpacing) {
            ForEach(0..<3, id: \.self) { _ in
                ArticleSkeletonCard()
            }
        }
        .padding(.horizontal, AppMetrics.List.horizontalInset)
        .frame(maxWidth: 520, maxHeight: .infinity, alignment: .top)
        .opacity(isDimmed ? 0.55 : 1)
        .clipped()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isDimmed = true
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Loading articles")
    }
}

private struct ArticleSkeletonCard: View {
    private let block = Color.white.opacity(0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: AppMetrics.Card.imageCornerRadius)
                .fill(block)
                .aspectRatio(345.0 / 194.0, contentMode: .fit)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Capsule().fill(block).frame(height: 14)
                Capsule().fill(block).frame(width: 220, height: 14)
            }
            .frame(maxWidth: .infinity, minHeight: 45, alignment: .leading)

            HStack {
                Capsule().fill(block).frame(width: 118, height: 14)
                Spacer()
                RoundedRectangle(cornerRadius: AppMetrics.Card.buttonCornerRadius)
                    .fill(block)
                    .frame(width: 148, height: 50)
            }
        }
        .padding(16)
        .background(
            Color(uiColor: AppColor.card),
            in: RoundedRectangle(cornerRadius: AppMetrics.Card.cornerRadius)
        )
    }
}

#Preview("Offline") {
    ContentStateView(kind: .offline, onRetry: {})
}

#Preview("Loading") {
    ContentStateView(kind: .loading)
}
