import XCTest
@testable import MemoryToastCore

final class SingleInstancePolicyTests: XCTestCase {
    func testAllowsLaunchWhenBundleIdentifierIsMissing() {
        let policy = SingleInstancePolicy()

        let decision = policy.decision(
            bundleIdentifier: nil,
            currentProcessIdentifier: 100,
            runningProcessIdentifiers: [100, 200]
        )

        XCTAssertEqual(decision, .continueLaunching)
    }

    func testAllowsLaunchWhenNoOtherMatchingProcessExists() {
        let policy = SingleInstancePolicy()

        let decision = policy.decision(
            bundleIdentifier: "com.example.MemoryToastTool",
            currentProcessIdentifier: 100,
            runningProcessIdentifiers: [100]
        )

        XCTAssertEqual(decision, .continueLaunching)
    }

    func testPrefersExistingMatchingProcessWhenDuplicateIsRunning() {
        let policy = SingleInstancePolicy()

        let decision = policy.decision(
            bundleIdentifier: "com.example.MemoryToastTool",
            currentProcessIdentifier: 100,
            runningProcessIdentifiers: [300, 100, 200]
        )

        XCTAssertEqual(decision, .activateExistingAndTerminateCurrent(existingProcessIdentifier: 300))
    }
}
