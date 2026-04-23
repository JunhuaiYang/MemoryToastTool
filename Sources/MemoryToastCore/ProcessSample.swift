import Foundation

public struct ProcessSample: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let appName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let isRunning: Bool

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        appName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        isRunning: Bool
    ) {
        self.pid = pid
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.isRunning = isRunning
    }
}
