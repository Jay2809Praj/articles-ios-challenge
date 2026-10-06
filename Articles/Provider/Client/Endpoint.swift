import Foundation

/// The remote resources the app talks to.
enum Endpoint {
    case articles

    var url: URL {
        switch self {
        case .articles:
            // Compile-time constant, validated by the unit tests.
            URL(string: "https://mocki.io/v1/9f09ed09-d8ca-48c7-9957-dec39e745321")!
        }
    }

    /// Short name used in logs.
    var name: String {
        switch self {
        case .articles: "articles"
        }
    }
}
