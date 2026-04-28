import Foundation

public enum MemoryPressureLevel: String, Codable, Equatable, Comparable, Sendable {
    case normal
    case warning
    case critical

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .normal:
            return 0
        case .warning:
            return 1
        case .critical:
            return 2
        }
    }
}

public struct MemorySnapshot: Equatable, Sendable {
    public let totalMemoryBytes: UInt64
    public let usedMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let failedProcessMemorySampleCount: Int
    public let processTreeRoots: [ProcessTreeNode]
    public let processes: [ProcessSample]

    public var processTreeMemoryBytes: UInt64 {
        processTreeRoots.reduce(0) { partialResult, root in
            partialResult + root.aggregateMemoryBytes
        }
    }

    public var unattributedMemoryBytes: UInt64 {
        let totalAccountedMemoryBytes = usedMemoryBytes + swapUsedBytes
        return totalAccountedMemoryBytes > processTreeMemoryBytes ? totalAccountedMemoryBytes - processTreeMemoryBytes : 0
    }

    public var usedMemoryRatio: Double {
        guard totalMemoryBytes > 0 else {
            return 0
        }

        return Double(usedMemoryBytes) / Double(totalMemoryBytes)
    }

    public init(
        totalMemoryBytes: UInt64,
        usedMemoryBytes: UInt64,
        availableMemoryBytes: UInt64,
        swapUsedBytes: UInt64,
        pressureLevel: MemoryPressureLevel,
        failedProcessMemorySampleCount: Int = 0,
        processTreeRoots: [ProcessTreeNode] = [],
        processes: [ProcessSample]
    ) {
        self.totalMemoryBytes = totalMemoryBytes
        self.usedMemoryBytes = usedMemoryBytes
        self.availableMemoryBytes = availableMemoryBytes
        self.swapUsedBytes = swapUsedBytes
        self.pressureLevel = pressureLevel
        self.failedProcessMemorySampleCount = failedProcessMemorySampleCount
        self.processTreeRoots = processTreeRoots
        self.processes = processes
    }
}
