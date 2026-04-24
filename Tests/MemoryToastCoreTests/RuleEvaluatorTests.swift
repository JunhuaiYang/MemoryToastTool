import XCTest
@testable import MemoryToastCore

final class RuleEvaluatorTests: XCTestCase {
    func testEvaluatorMatchesAvailableMemoryAndSwapRules() {
        let snapshot = MemorySnapshot(
            totalMemoryBytes: 36_000_000_000,
            usedMemoryBytes: 32_000_000_000,
            availableMemoryBytes: 1_500_000_000,
            swapUsedBytes: 5_000_000_000,
            pressureLevel: .warning,
            processes: []
        )

        let rules = [
            AlertRule.availableMemoryBelow(bytes: 2_000_000_000),
            AlertRule.swapUsedAbove(bytes: 4_000_000_000)
        ]

        let result = RuleEvaluator().evaluate(snapshot: snapshot, rules: rules)

        XCTAssertTrue(result.isTriggered)
        XCTAssertEqual(result.reasons.count, 2)
    }

    func testEvaluatorMatchesPressureRule() {
        let snapshot = MemorySnapshot(
            totalMemoryBytes: 36_000_000_000,
            usedMemoryBytes: 20_000_000_000,
            availableMemoryBytes: 12_000_000_000,
            swapUsedBytes: 0,
            pressureLevel: .critical,
            processes: []
        )

        let result = RuleEvaluator().evaluate(
            snapshot: snapshot,
            rules: [.pressureAtLeast(level: .critical)]
        )

        XCTAssertTrue(result.isTriggered)
        XCTAssertEqual(result.matches, [.pressureAtLeast(level: .critical)])
        XCTAssertEqual(result.reasons, ["pressure >= critical"])
    }
}
