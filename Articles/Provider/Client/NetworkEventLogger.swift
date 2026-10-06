import Alamofire
import Foundation
@preconcurrency import XCGLogger

/// Logs the lifecycle of every Alamofire request through XCGLogger.
///
/// - `debug`: outgoing requests
/// - `info`: successful responses
/// - `verbose`: response metrics that are only useful while diagnosing
/// - `warning`: cancelled requests
/// - `error`: failed requests and unexpected status codes
final class NetworkEventLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.jayprajapati.articles.network-logger")

    private let logger: XCGLogger

    init(logger: XCGLogger) {
        self.logger = logger
    }

    func requestDidResume(_ request: Request) {
        guard let urlRequest = request.request else { return }
        let method = urlRequest.httpMethod ?? "GET"
        let url = urlRequest.url?.absoluteString ?? "<unknown url>"
        logger.debug("→ \(method) \(url)")
    }

    func request<Value: Sendable>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        let url = request.request?.url?.absoluteString ?? "<unknown url>"
        let duration = String(format: "%.0f ms", (response.metrics?.taskInterval.duration ?? 0) * 1000)

        switch response.result {
        case .success:
            let status = response.response?.statusCode ?? 0
            logger.info("← \(status) \(url) (\(response.data?.count ?? 0) bytes, \(duration))")
            logger.verbose("Response headers: \(response.response?.allHeaderFields ?? [:])")
        case .failure(let error) where error.isExplicitlyCancelledError:
            logger.warning("✕ Cancelled \(url)")
        case .failure(let error):
            let status = response.response.map { "\($0.statusCode) " } ?? ""
            logger.error("← \(status)\(url) failed after \(duration): \(error.localizedDescription)")
        }
    }
}
