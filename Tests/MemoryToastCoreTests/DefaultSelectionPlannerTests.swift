import XCTest
@testable import MemoryToastCore

final class DefaultSelectionPlannerTests: XCTestCase {
    func testIgnoredAppsAreSkippedWhenPickingDefaultSelection() {
        let processes = [
            ProcessSample(pid: 1, appName: "Safari", bundleIdentifier: "com.apple.Safari", memoryBytes: 900, isRunning: true),
            ProcessSample(pid: 2, appName: "Chrome", bundleIdentifier: "com.google.Chrome", memoryBytes: 800, isRunning: true),
            ProcessSample(pid: 3, appName: "Slack", bundleIdentifier: "com.tinyspeck.slackmacgap", memoryBytes: 700, isRunning: true),
            ProcessSample(pid: 4, appName: "Arc", bundleIdentifier: "company.thebrowser.Browser", memoryBytes: 600, isRunning: true)
        ]

        let selection = DefaultSelectionPlanner().selectDefaultPIDs(
            from: processes,
            count: 2,
            ignoredBundleIdentifiers: ["com.apple.Safari", "com.tinyspeck.slackmacgap"]
        )

        XCTAssertEqual(selection, [2, 4])
    }
}
