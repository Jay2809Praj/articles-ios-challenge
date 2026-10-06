import Foundation

extension NetworkError {
    /// Copy shown to the user when a request fails and nothing is cached.
    var userMessage: String {
        switch self {
        case .offline:
            "Please connect to the internet and try again."
        case .timedOut:
            "The request took too long. Please try again."
        case .server(let statusCode):
            "The server responded with an error (\(statusCode)). Please try again later."
        case .invalidResponse:
            "We couldn’t read the articles. Please try again later."
        case .cancelled, .unknown:
            "Please try again."
        }
    }
}
