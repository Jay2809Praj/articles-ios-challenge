import Foundation

/// Observes whether the device currently has a network path.
protocol ReachabilityProviderProtocol: AnyObject {
    var isReachable: Bool { get }
    /// Called on the main queue every time reachability flips.
    var onReachabilityChange: ((Bool) -> Void)? { get set }

    func startMonitoring()
    func stopMonitoring()
}
