import Alamofire
import Foundation

/// Translates Alamofire / URLSession failures into `NetworkError`.
enum NetworkErrorMapper {
    private static let offlineCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .dataNotAllowed,
        .cannotFindHost,
        .cannotConnectToHost,
        .dnsLookupFailed,
        .internationalRoamingOff
    ]

    static func map(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        if let afError = error as? AFError {
            return map(afError)
        }
        if let urlError = error as? URLError {
            return map(urlError)
        }
        return .unknown(description: error.localizedDescription)
    }

    private static func map(_ error: AFError) -> NetworkError {
        if error.isExplicitlyCancelledError {
            return .cancelled
        }
        if let statusCode = error.responseCode {
            return .server(statusCode: statusCode)
        }
        if error.isResponseSerializationError {
            return .invalidResponse
        }
        if let urlError = error.underlyingError as? URLError {
            return map(urlError)
        }
        return .unknown(description: error.localizedDescription)
    }

    private static func map(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        case let code where offlineCodes.contains(code):
            .offline
        default:
            .unknown(description: error.localizedDescription)
        }
    }
}
