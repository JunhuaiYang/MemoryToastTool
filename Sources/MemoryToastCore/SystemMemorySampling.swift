import Foundation

public struct SystemMemorySample: Equatable, Sendable {
    public let totalMemoryBytes: UInt64
    public let usedMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel

    public init(
        totalMemoryBytes: UInt64,
        usedMemoryBytes: UInt64,
        availableMemoryBytes: UInt64,
        swapUsedBytes: UInt64,
        pressureLevel: MemoryPressureLevel
    ) {
        self.totalMemoryBytes = totalMemoryBytes
        self.usedMemoryBytes = usedMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
    }
}

public protocol SystemMemorySampling: Sendable {
    func sampleSystemMemory() async throws -> SystemMemorySample
}

public struct LiveSystemMemorySampler: SystemMemorySampling {
    public init() {}

    public func sampleSystemMemory() async throws -> SystemMemorySample {
        let totalMemory = ProcessInfo.processInfo.physicalMemory

        return SystemMemorySample(
            totalMemoryBytes: totalMemory,
            usedMemoryBytes: 0,
            availableMemoryBytes: totalMemory,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )
    }
}
