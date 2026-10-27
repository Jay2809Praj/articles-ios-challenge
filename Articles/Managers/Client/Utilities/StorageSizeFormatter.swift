import Foundation

/// Renders byte counts the way the Saved section shows them ("12.4 MB of 50 MB used").
enum StorageSizeFormatter {
    private static let bytesPerMegabyte = 1024.0 * 1024.0

    /// "0.7 MB", "12.4 MB", "50 MB" – one decimal unless the value is whole,
    /// and never "0.0 MB" for something that exists.
    static func megabytes(_ bytes: Int64) -> String {
        let megabytes = Double(max(bytes, 0)) / bytesPerMegabyte
        if bytes > 0, megabytes < 0.1 {
            return "<0.1 MB"
        }
        let rounded = (megabytes * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) MB"
        }
        return String(format: "%.1f MB", rounded)
    }

    /// "12.4 MB of 50 MB used"
    static func usageSummary(used: Int64, limit: Int64) -> String {
        "\(megabytes(used)) of \(megabytes(limit)) used"
    }
}
