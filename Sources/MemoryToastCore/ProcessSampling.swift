import AppKit
import Darwin
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
                memoryBytes: residentMemoryBytes(for: app.processIdentifier),
                isRunning: !app.isTerminated
            )
        }
    }

    private func residentMemoryBytes(for pid: pid_t) -> UInt64 {
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V2, reboundPointer)
            }
        }

        guard result == 0 else {
            return 0
        }

        return usage.ri_resident_size
    }
}
