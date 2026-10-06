import Foundation

/// Retains a connectivity observation; release it to stop observing.
final class ConnectivityObservation {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    deinit {
        onCancel()
    }
}

/// Tells the UI whether the device is online and when that changes.
protocol ConnectivityManagerProtocol: AnyObject {
    var isOnline: Bool { get }

    /// Registers a handler that runs on the main queue whenever connectivity
    /// changes. Keep the returned token alive for as long as updates are wanted.
    func observe(_ handler: @escaping (_ isOnline: Bool) -> Void) -> ConnectivityObservation
}
