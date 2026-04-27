import XCTest
@testable import MemoryToastCore

final class ProcessTreeBuilderTests: XCTestCase {
    func testAggregatesChildrenIntoTopmostEligibleRoot() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 10, isRunning: true),
            RawProcessSample(pid: 100, ppid: 1, processName: "Google Chrome", bundleIdentifier: "com.google.Chrome", memoryBytes: 200, isRunning: true),
            RawProcessSample(pid: 101, ppid: 100, processName: "Google Chrome Helper", bundleIdentifier: nil, memoryBytes: 300, isRunning: true),
            RawProcessSample(pid: 102, ppid: 101, processName: "Google Chrome GPU", bundleIdentifier: nil, memoryBytes: 500, isRunning: true),
        ])

        XCTAssertEqual(roots.map(\.pid), [100])
        XCTAssertEqual(roots.first?.aggregateMemoryBytes, 1_000)
        XCTAssertEqual(roots.first?.children.map(\.pid), [101])
        XCTAssertEqual(roots.first?.children.first?.children.map(\.pid), [102])
    }

    func testOrphanBackgroundProcessBecomesStandaloneRoot() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 700, ppid: 1, processName: "worker", bundleIdentifier: nil, memoryBytes: 321, isRunning: true),
        ])

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].pid, 700)
        XCTAssertEqual(roots[0].aggregateMemoryBytes, 321)
    }

    func testStopsAtSystemRootBoundary() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 0, ppid: 0, processName: "kernel_task", bundleIdentifier: nil, memoryBytes: 1, isRunning: true),
            RawProcessSample(pid: 10, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 1, isRunning: true),
            RawProcessSample(pid: 500, ppid: 10, processName: "daemon-a", bundleIdentifier: nil, memoryBytes: 111, isRunning: true),
            RawProcessSample(pid: 501, ppid: 500, processName: "daemon-b", bundleIdentifier: nil, memoryBytes: 222, isRunning: true),
        ])

        XCTAssertEqual(roots.map(\.pid), [500])
        XCTAssertEqual(roots[0].aggregateMemoryBytes, 333)
    }
}
