@testable import Articles
import XCTest

final class EndpointTests: XCTestCase {
    func testArticlesEndpointIsSecureHTTP() {
        XCTAssertEqual(Endpoint.articles.url.scheme, "https")
        XCTAssertEqual(Endpoint.articles.url.host, "mocki.io")
    }
}
