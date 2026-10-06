import Foundation
import Reachability
import XCGLogger

/// ReachabilitySwift-backed implementation of `ReachabilityProviderProtocol`.
final class ReachabilityProvider: ReachabilityProviderProtocol {
    var onReachabilityChange: ((Bool) -> Void)?

    var isReachable: Bool {
        // When the notifier could not be created we assume the best and let
        // the request itself report the failure.
        guard let reachability else { return true }
        return reachability.connection != .unavailable
    }

    private let reachability: Reachability?
    private let logger: XCGLogger

    init(logger: XCGLogger) {
        self.logger = logger
        do {
            reachability = try Reachability(notificationQueue: .main)
        } catch {
            reachability = nil
            logger.error("Reachability could not be created: \(error)")
        }
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard let reachability else { return }

        reachability.whenReachable = { [weak self] reachability in
            self?.logger.info("Network reachable via \(reachability.connection.description)")
            self?.onReachabilityChange?(true)
        }
        reachability.whenUnreachable = { [weak self] _ in
            self?.logger.warning("Network unreachable")
            self?.onReachabilityChange?(false)
        }

        do {
            try reachability.startNotifier()
        } catch {
            logger.error("Reachability notifier failed to start: \(error)")
        }
    }

    func stopMonitoring() {
        reachability?.stopNotifier()
    }
}
