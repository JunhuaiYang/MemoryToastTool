import XCTest
@testable import MemoryToastCore

final class MemoryMonitorTests: XCTestCase {
    func testMonitorReturnsRootsSortedByAggregateMemoryDescending() async throws {
        let systemSampler = StubSystemMemorySampler(
            snapshot: SystemMemorySample(
                totalMemoryBytes: 36_000,
                usedMemoryBytes: 30_000,
                availableMemoryBytes: 2_000,
                swapUsedBytes: 5_000,
                pressureLevel: .warning
            )
        )
        let processSampler = StubProcessSampler(rawProcesses: [
            RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 0, isRunning: true),
            RawProcessSample(pid: 10, ppid: 1, processName: "App A", bundleIdentifier: "a", memoryBytes: 100, isRunning: true),
            RawProcessSample(pid: 11, ppid: 10, processName: "App A Helper", bundleIdentifier: nil, memoryBytes: 700, isRunning: true),
            RawProcessSample(pid: 20, ppid: 1, processName: "App B", bundleIdentifier: "b", memoryBytes: 500, isRunning: true),
        ])

        let snapshot = try await MemoryMonitor(
            systemSampler: systemSampler,
            processSampler: processSampler,
            treeBuilder: ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])
        ).sample()

        XCTAssertEqual(snapshot.processes.map(\.pid), [10, 20])
        XCTAssertEqual(snapshot.processes.map(\.aggregateMemoryBytes), [800, 500])
        XCTAssertEqual(snapshot.processTreeRoots.map(\.pid), [10, 20])
        XCTAssertEqual(snapshot.pressureLevel, .warning)
    }

    func testMonitorReportsTreeTotalAndMissingProcessMemoryCoverage() async throws {
        let systemSampler = StubSystemMemorySampler(
            snapshot: SystemMemorySample(
                totalMemoryBytes: 40_000,
                usedMemoryBytes: 30_000,
                availableMemoryBytes: 10_000,
                swapUsedBytes: 0,
                pressureLevel: .warning
            )
        )
        let processSampler = StubProcessSampler(rawProcesses: [
            RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 0, isRunning: true),
            RawProcessSample(pid: 10, ppid: 1, processName: "App A", bundleIdentifier: "a", memoryBytes: 1_000, isRunning: true),
            RawProcessSample(pid: 11, ppid: 10, processName: "App A Helper", bundleIdentifier: nil, memoryBytes: 500, isRunning: true),
            RawProcessSample(pid: 20, ppid: 1, processName: "App B", bundleIdentifier: "b", memoryBytes: 0, didSampleMemory: false, isRunning: true),
        ])

        let snapshot = try await MemoryMonitor(
            systemSampler: systemSampler,
            processSampler: processSampler,
            treeBuilder: ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])
        ).sample()

        XCTAssertEqual(snapshot.processTreeMemoryBytes, 1_500)
        XCTAssertEqual(snapshot.failedProcessMemorySampleCount, 1)
        XCTAssertEqual(snapshot.unattributedMemoryBytes, 28_500)
    }

    func testMonitorAddsSwapToUnattributedMemoryCoverageGap() async throws {
        let systemSampler = StubSystemMemorySampler(
            snapshot: SystemMemorySample(
                totalMemoryBytes: 40_000,
                usedMemoryBytes: 30_000,
                availableMemoryBytes: 10_000,
                swapUsedBytes: 4_000,
                pressureLevel: .warning
            )
        )
        let processSampler = StubProcessSampler(rawProcesses: [
            RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 0, isRunning: true),
            RawProcessSample(pid: 10, ppid: 1, processName: "App A", bundleIdentifier: "a", memoryBytes: 1_000, isRunning: true),
            RawProcessSample(pid: 11, ppid: 10, processName: "App A Helper", bundleIdentifier: nil, memoryBytes: 500, isRunning: true),
        ])

        let snapshot = try await MemoryMonitor(
            systemSampler: systemSampler,
            processSampler: processSampler,
            treeBuilder: ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])
        ).sample()

        XCTAssertEqual(snapshot.processTreeMemoryBytes, 1_500)
        XCTAssertEqual(snapshot.unattributedMemoryBytes, 32_500)
    }
}

private struct StubSystemMemorySampler: SystemMemorySampling {
    let snapshot: SystemMemorySample

    func sampleSystemMemory() async throws -> SystemMemorySample {
        snapshot
    }
}
