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

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return internetDateTime.date(from: string) ?? fractionalDateTime.date(from: string)
    }

    static func displayString(from string: String?) -> String? {
        date(from: string).map(display.string(from:))
    }

    /// "5 minutes ago" – used to tell the user how old cached content is.
    static func relativeString(for date: Date, relativeTo reference: Date = Date()) -> String {
        guard reference.timeIntervalSince(date) >= 60 else { return "just now" }
        return relative.localizedString(for: date, relativeTo: reference)
    }
}
