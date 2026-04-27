import Foundation

public struct RawProcessSample: Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let processName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let didSampleMemory: Bool
    public let isRunning: Bool

    public init(
        pid: Int32,
        ppid: Int32,
        processName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        didSampleMemory: Bool = true,
        isRunning: Bool
    ) {
        self.pid = pid
        self.ppid = ppid
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.didSampleMemory = didSampleMemory
        self.isRunning = isRunning
    }
}
