import XCTest
@testable import MemoryToastCore

final class AlertPresentationPolicyTests: XCTestCase {
    func testDoesNotPresentWhileSnoozeIsActive() {
        let shouldPresent = AlertPresentationPolicy().shouldPresentAlert(
            triggerReasons: [.swapUsedAbove(bytes: 1)],
            isAlertActive: false,
            isIgnoringCurrentIncident: false,
            snoozeUntil: Date(timeIntervalSince1970: 200),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertFalse(shouldPresent)
    }

    func testIgnoreOnceSuppressesUntilAlertReasonsClear() {
        let policy = AlertPresentationPolicy()

        XCTAssertTrue(policy.shouldKeepIgnoringCurrentIncident(
            isIgnoringCurrentIncident: true,
            triggerReasons: [.swapUsedAbove(bytes: 1)]
        ))
        XCTAssertFalse(policy.shouldKeepIgnoringCurrentIncident(
            isIgnoringCurrentIncident: true,
            triggerReasons: []
        ))
    }
}
