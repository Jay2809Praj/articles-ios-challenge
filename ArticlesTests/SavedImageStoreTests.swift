@testable import Articles
import XCTest

final class SavedImageStoreTests: XCTestCase {
    private var directory: URL!
    private var store: SavedImageStore!

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SavedImageStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = SavedImageStore(directoryURL: directory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    func testSaveWritesTheFileAndReportsItsRealSize() {
        let data = Data(repeating: 7, count: 12_345)

        let bytes = store.save(data, for: "https://example.com/a|2025|Title")

        XCTAssertEqual(bytes, 12_345)
        let url = store.imageURL(for: "https://example.com/a|2025|Title")
        XCTAssertNotNil(url)
        XCTAssertEqual(try Data(contentsOf: url!), data)
        XCTAssertEqual(store.byteSize(for: "https://example.com/a|2025|Title"), 12_345)
        XCTAssertTrue(url!.path.hasPrefix(directory.path), "Files live in the directory the app owns")
    }

    func testUnknownArticleHasNoImage() {
        XCTAssertNil(store.imageURL(for: "missing"))
        XCTAssertEqual(store.byteSize(for: "missing"), 0)
    }

    func testEmptyDataIsNotStored() {
        XCTAssertEqual(store.save(Data(), for: "empty"), 0)
        XCTAssertNil(store.imageURL(for: "empty"))
    }

    func testSavingAgainReplacesTheFile() {
        store.save(Data(repeating: 1, count: 100), for: "a")
        let bytes = store.save(Data(repeating: 2, count: 50), for: "a")

        XCTAssertEqual(bytes, 50)
        XCTAssertEqual(store.byteSize(for: "a"), 50)
    }

    func testRemoveDeletesOnlyThatImage() {
        store.save(Data([1]), for: "a")
        store.save(Data([2]), for: "b")

        store.remove(for: "a")

        XCTAssertNil(store.imageURL(for: "a"))
        XCTAssertNotNil(store.imageURL(for: "b"))
    }

    func testRemoveAllDeletesEverything() {
        store.save(Data([1]), for: "a")
        store.save(Data([2]), for: "b")

        store.removeAll()

        XCTAssertNil(store.imageURL(for: "a"))
        XCTAssertNil(store.imageURL(for: "b"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testDefaultDirectoryIsUnderApplicationSupport() {
        let url = SavedImageStore().imageURL(for: "nothing-stored")
        XCTAssertNil(url)

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let defaultStore = SavedImageStore()
        defaultStore.save(Data([9]), for: "probe")
        defer { defaultStore.remove(for: "probe") }

        XCTAssertTrue(defaultStore.imageURL(for: "probe")!.path.hasPrefix(support.path))
        XCTAssertTrue(defaultStore.imageURL(for: "probe")!.path.contains(AppConstants.SavedArticles.imagesDirectory))
    }
}
