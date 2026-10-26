import CryptoKit
import Foundation

/// Keeps one image file per saved article under Application Support. Files
/// there are not purged by the system and have no expiry, so a saved article
/// opens with its image for as long as it stays saved.
final class SavedImageStore: SavedImageStoreProtocol {
    private let directoryURL: URL
    private let fileManager: FileManager

    /// - Parameter directoryURL: defaults to
    ///   `Application Support/SavedArticles/Images`; tests pass a temporary folder.
    init(directoryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directoryURL = directoryURL ?? Self.defaultDirectory(fileManager: fileManager)
    }

    func imageURL(for articleID: String) -> URL? {
        let url = fileURL(for: articleID)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    @discardableResult
    func save(_ data: Data, for articleID: String) -> Int64 {
        guard !data.isEmpty else { return 0 }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let url = fileURL(for: articleID)
            try data.write(to: url, options: .atomic)
            return byteSize(at: url)
        } catch {
            return 0
        }
    }

    func byteSize(for articleID: String) -> Int64 {
        byteSize(at: fileURL(for: articleID))
    }

    func remove(for articleID: String) {
        try? fileManager.removeItem(at: fileURL(for: articleID))
    }

    func removeAll() {
        try? fileManager.removeItem(at: directoryURL)
    }

    // MARK: - Private

    private static func defaultDirectory(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent(AppConstants.SavedArticles.imagesDirectory, isDirectory: true)
    }

    private func fileURL(for articleID: String) -> URL {
        // Identifiers contain URLs; a hash makes a safe, fixed-length file name.
        let digest = SHA256.hash(data: Data(articleID.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directoryURL.appendingPathComponent(name).appendingPathExtension("img")
    }

    /// The real footprint as reported by the file system.
    private func byteSize(at url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber
        else {
            return 0
        }
        return size.int64Value
    }
}
