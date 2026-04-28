import XCTest
@testable import MemoryToastCore

final class MonitoringCadenceTests: XCTestCase {
    func testUsesConfiguredDetectionIntervalWhenAlertIsInactive() {
        XCTAssertEqual(
            MonitoringCadence.refreshIntervalSeconds(detectionIntervalSeconds: 30, isAlertActive: false),
            30
        )
    }

    func testUsesOneSecondRefreshWhileAlertIsActive() {
        XCTAssertEqual(
            MonitoringCadence.refreshIntervalSeconds(detectionIntervalSeconds: 30, isAlertActive: true),
            1
        )
    }
}
