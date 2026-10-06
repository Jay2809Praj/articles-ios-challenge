import Foundation

/// Fans reachability changes out to any number of observers.
final class ConnectivityManager: ConnectivityManagerProtocol {
    var isOnline: Bool { provider.isReachable }

    private let provider: ReachabilityProviderProtocol
    private var handlers: [UUID: (Bool) -> Void] = [:]
    private var lastKnownState: Bool

    init(provider: ReachabilityProviderProtocol) {
        self.provider = provider
        lastKnownState = provider.isReachable

        provider.onReachabilityChange = { [weak self] isOnline in
            self?.reachabilityChanged(isOnline)
        }
        provider.startMonitoring()
    }

    deinit {
        provider.stopMonitoring()
    }

    func observe(_ handler: @escaping (Bool) -> Void) -> ConnectivityObservation {
        let id = UUID()
        handlers[id] = handler
        return ConnectivityObservation { [weak self] in
            self?.handlers[id] = nil
        }
    }

    private func reachabilityChanged(_ isOnline: Bool) {
        // Reachability also fires when switching between Wi-Fi and cellular;
        // observers only care about actual online/offline transitions.
        guard isOnline != lastKnownState else { return }
        lastKnownState = isOnline
        handlers.values.forEach { $0(isOnline) }
    }
}
