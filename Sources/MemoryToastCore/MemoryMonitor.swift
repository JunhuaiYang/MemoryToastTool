import Foundation

public struct MemoryMonitor: Sendable {
    public let systemSampler: SystemMemorySampling
    public let processSampler: ProcessSampling
    public let treeBuilder: ProcessTreeBuilder

    public init(
        systemSampler: SystemMemorySampling = LiveSystemMemorySampler(),
        processSampler: ProcessSampling = LiveProcessSampler(),
        treeBuilder: ProcessTreeBuilder = ProcessTreeBuilder()
    ) {
        self.systemSampler = systemSampler
        self.processSampler = processSampler
        self.treeBuilder = treeBuilder
    }

    public func sample() async throws -> MemorySnapshot {
        let system = try await systemSampler.sampleSystemMemory()
        let rawProcesses = try await processSampler.sampleProcesses()
        let failedProcessMemorySampleCount = rawProcesses.reduce(0) { partialResult, sample in
            partialResult + (sample.didSampleMemory ? 0 : 1)
        }
        let processTreeRoots = treeBuilder.buildTree(from: rawProcesses)
        let sortedProcesses = processTreeRoots.map { root in
            ProcessSample(
                pid: root.pid,
                parentPID: root.parentPID,
                appName: root.processName,
                bundleIdentifier: root.bundleIdentifier,
                memoryBytes: root.memoryBytes,
                aggregateMemoryBytes: root.aggregateMemoryBytes,
                isRunning: root.isRunning,
                childPIDs: root.children.map(\.pid)
            )
        }

        return MemorySnapshot(
            totalMemoryBytes: system.totalMemoryBytes,
            usedMemoryBytes: system.usedMemoryBytes,
            availableMemoryBytes: system.availableMemoryBytes,
            swapUsedBytes: system.swapUsedBytes,
            pressureLevel: system.pressureLevel,
            failedProcessMemorySampleCount: failedProcessMemorySampleCount,
            processTreeRoots: processTreeRoots,
            processes: sortedProcesses
        )
    }
}
