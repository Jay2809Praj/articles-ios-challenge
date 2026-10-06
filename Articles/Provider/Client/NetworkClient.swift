import Alamofire
import Foundation

/// Alamofire-backed implementation of `NetworkClientProtocol`.
final class NetworkClient: NetworkClientProtocol {
    private let session: Session

    init(session: Session) {
        self.session = session
    }

    func data(from endpoint: Endpoint) async throws -> Data {
        let request = session
            .request(endpoint.url, method: .get)
            .validate(statusCode: 200..<300)

        do {
            return try await request.serializingData().value
        } catch {
            throw NetworkErrorMapper.map(error)
        }
    }
}
