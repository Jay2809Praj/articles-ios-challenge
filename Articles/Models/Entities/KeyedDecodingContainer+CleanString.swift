import Foundation

extension KeyedDecodingContainer {
    /// Decodes a string leniently: a missing key, `null`, a non-string value,
    /// or a blank string all collapse to `nil`.
    func decodeCleanString(forKey key: Key) -> String? {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
