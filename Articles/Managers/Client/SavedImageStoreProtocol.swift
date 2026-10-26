import Foundation

/// Where the images of saved articles live, owned by the app rather than by
/// an image library's temporary cache.
protocol SavedImageStoreProtocol {
    /// The stored image file for the article, or `nil` when there is none.
    func imageURL(for articleID: String) -> URL?

    /// Writes the image and returns the bytes it occupies on disk, `0` on failure.
    @discardableResult
    func save(_ data: Data, for articleID: String) -> Int64

    /// Bytes the stored image occupies, `0` when there is none.
    func byteSize(for articleID: String) -> Int64

    func remove(for articleID: String)

    func removeAll()
}
