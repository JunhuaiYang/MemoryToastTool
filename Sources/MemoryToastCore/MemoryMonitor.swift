import Foundation

public struct MemoryMonitor: Sendable {
    public let systemSampler: SystemMemorySampling
    public let processSampler: ProcessSampling

    public init(
        systemSampler: SystemMemorySampling = LiveSystemMemorySampler(),
        processSampler: ProcessSampling = LiveProcessSampler()
    ) {
        self.systemSampler = systemSampler
        self.processSampler = processSampler
    }

    public func sample() async throws -> MemorySnapshot {
        let system = try await systemSampler.sampleSystemMemory()
        let processSamples = try await processSampler.sampleProcesses()
        let sortedProcesses = processSamples.sorted { lhs, rhs in
            lhs.memoryBytes > rhs.memoryBytes
        }

        return MemorySnapshot(
            totalMemoryBytes: system.totalMemoryBytes,
            usedMemoryBytes: system.usedMemoryBytes,
            availableMemoryBytes: system.availableMemoryBytes,
            swapUsedBytes: system.swapUsedBytes,
            pressureLevel: system.pressureLevel,
            processes: sortedProcesses
        )
    }
}
