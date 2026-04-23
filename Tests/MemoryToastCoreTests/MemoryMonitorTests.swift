import XCTest
@testable import MemoryToastCore

final class MemoryMonitorTests: XCTestCase {
    func testMonitorReturnsProcessesSortedByMemoryDescending() async throws {
        let systemSampler = StubSystemMemorySampler(
            snapshot: SystemMemorySample(
                totalMemoryBytes: 36_000,
                usedMemoryBytes: 30_000,
                availableMemoryBytes: 2_000,
                swapUsedBytes: 5_000,
                pressureLevel: .warning
            )
        )
        let processSampler = StubProcessSampler(processes: [
            ProcessSample(pid: 1, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 200, isRunning: true),
            ProcessSample(pid: 2, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 900, isRunning: true),
            ProcessSample(pid: 3, appName: "Xcode", bundleIdentifier: "xcode", memoryBytes: 600, isRunning: true)
        ])

        let snapshot = try await MemoryMonitor(
            systemSampler: systemSampler,
            processSampler: processSampler
        ).sample()

        XCTAssertEqual(snapshot.processes.map(\.appName), ["Chrome", "Xcode", "Slack"])
        XCTAssertEqual(snapshot.pressureLevel, .warning)
    }
}

private struct StubSystemMemorySampler: SystemMemorySampling {
    let snapshot: SystemMemorySample

    func sampleSystemMemory() async throws -> SystemMemorySample {
        snapshot
    }
}

private struct StubProcessSampler: ProcessSampling {
    let processes: [ProcessSample]

    func sampleProcesses() async throws -> [ProcessSample] {
        processes
    }
}
