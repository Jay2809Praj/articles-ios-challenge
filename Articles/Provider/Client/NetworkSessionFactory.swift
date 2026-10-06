import Alamofire
import Foundation

/// Builds the Alamofire `Session` shared by every provider.
enum NetworkSessionFactory {
    static func makeSession(eventMonitors: [EventMonitor]) -> Session {
        let configuration = URLSessionConfiguration.af.default
        configuration.timeoutIntervalForRequest = AppConstants.Network.requestTimeout
        configuration.timeoutIntervalForResource = AppConstants.Network.resourceTimeout
        // Offline support is handled explicitly by `ArticlesCache`; a stale
        // URLCache hit would hide real connectivity failures from the app.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil

        return Session(configuration: configuration, eventMonitors: eventMonitors)
    }
}
