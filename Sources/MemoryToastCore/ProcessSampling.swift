import AppKit
import Foundation

public protocol ProcessSampling: Sendable {
    func sampleProcesses() async throws -> [ProcessSample]
}

public struct LiveProcessSampler: ProcessSampling {
    public init() {}

    public func sampleProcesses() async throws -> [ProcessSample] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            ProcessSample(
                pid: app.processIdentifier,
                appName: app.localizedName ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier,
                memoryBytes: 0,
                isRunning: !app.isTerminated
            )
        }
    }
}
