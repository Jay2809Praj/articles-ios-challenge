import Foundation

/// Parses the API's ISO-8601 timestamps and renders them the way the design
/// shows them ("24 Oct,2021").
enum ArticleDateFormatter {
    private static let internetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fractionalDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let display: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM,yyyy"
        return formatter
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return internetDateTime.date(from: string) ?? fractionalDateTime.date(from: string)
    }

    static func displayString(from string: String?) -> String? {
        date(from: string).map(display.string(from:))
    }

    /// Compact age as shown on the detail screen ("10h ago").
    static func shortRelativeString(from string: String?, relativeTo reference: Date = Date()) -> String? {
        date(from: string).map { shortRelativeString(for: $0, relativeTo: reference) }
    }

    static func shortRelativeString(for date: Date, relativeTo reference: Date = Date()) -> String {
        let seconds = max(0, Int(reference.timeIntervalSince(date)))
        let minute = 60, hour = 3_600, day = 86_400, week = 604_800, year = 31_536_000

        switch seconds {
        case ..<minute: return "Just now"
        case ..<hour: return "\(seconds / minute)m ago"
        case ..<day: return "\(seconds / hour)h ago"
        case ..<week: return "\(seconds / day)d ago"
        case ..<year: return "\(seconds / week)w ago"
        default: return "\(seconds / year)y ago"
        }
    }
}
