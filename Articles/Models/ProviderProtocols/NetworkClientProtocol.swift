import Foundation

/// The minimal HTTP surface the providers depend on.
protocol NetworkClientProtocol {
    /// Performs a GET request and returns the validated response body.
    /// - Throws: `NetworkError`.
    func data(from endpoint: Endpoint) async throws -> Data
}
