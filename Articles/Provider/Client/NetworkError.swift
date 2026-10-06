import Foundation

/// Every way a request can fail, reduced to what the app can act on.
enum NetworkError: Error, Equatable {
    /// No network path, or the connection dropped mid-flight.
    case offline
    case timedOut
    /// The server answered with a non-2xx status code.
    case server(statusCode: Int)
    /// The body could not be parsed into the expected shape.
    case invalidResponse
    case cancelled
    case unknown(description: String)

    /// `true` when waiting for connectivity is likely to fix the problem.
    var isConnectivityIssue: Bool {
        self == .offline || self == .timedOut
    }
}
