import Foundation

public struct ProcessTreeNode: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let parentPID: Int32?
    public let processName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let aggregateMemoryBytes: UInt64
    public let isRunning: Bool
    public let children: [ProcessTreeNode]

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        parentPID: Int32?,
        processName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        aggregateMemoryBytes: UInt64,
        isRunning: Bool,
        children: [ProcessTreeNode]
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.aggregateMemoryBytes = aggregateMemoryBytes
        self.isRunning = isRunning
        self.children = children
    }
}
