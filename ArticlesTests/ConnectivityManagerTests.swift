@testable import Articles
import XCTest

final class ConnectivityManagerTests: XCTestCase {
    func testStartsMonitoringAndReportsState() {
        let provider = MockReachabilityProvider()
        let manager = ConnectivityManager(provider: provider)

        XCTAssertTrue(provider.isMonitoring)
        XCTAssertTrue(manager.isOnline)
    }

    func testNotifiesObserversOnlyOnRealTransitions() {
        let provider = MockReachabilityProvider()
        let manager = ConnectivityManager(provider: provider)
        var events: [Bool] = []
        let observation = manager.observe { events.append($0) }

        provider.simulate(reachable: true)   // still online: Wi-Fi → cellular
        provider.simulate(reachable: false)
        provider.simulate(reachable: false)
        provider.simulate(reachable: true)

        XCTAssertEqual(events, [false, true])
        withExtendedLifetime(observation) {}
    }

    func testReleasingTheObservationStopsUpdates() {
        let provider = MockReachabilityProvider()
        let manager = ConnectivityManager(provider: provider)
        var events: [Bool] = []
        var observation: ConnectivityObservation? = manager.observe { events.append($0) }
        XCTAssertNotNil(observation)

        observation = nil
        provider.simulate(reachable: false)

        XCTAssertTrue(events.isEmpty)
    }
}
