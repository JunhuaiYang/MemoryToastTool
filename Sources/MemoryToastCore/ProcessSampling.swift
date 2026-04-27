import AppKit
import Darwin
import Foundation

public protocol ProcessSampling: Sendable {
    func sampleProcesses() async throws -> [RawProcessSample]
}

public struct LiveProcessSampler: ProcessSampling {
    public init() {}

    public func sampleProcesses() async throws -> [RawProcessSample] {
        let runningApplications = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map {
            ($0.processIdentifier, $0)
        })

        return allProcessIdentifiers().compactMap { pid in
            guard let processInfo = processInfo(for: pid) else {
                return nil
            }

            let runningApplication = runningApplications[pid]
            let memorySample = residentMemorySample(for: pid)

            return RawProcessSample(
                pid: pid,
                ppid: processInfo.ppid,
                processName: runningApplication?.localizedName ?? processInfo.name,
                bundleIdentifier: runningApplication?.bundleIdentifier,
                memoryBytes: memorySample.bytes,
                didSampleMemory: memorySample.didSampleMemory,
                isRunning: true
            )
        }
    }

    private func allProcessIdentifiers() -> [pid_t] {
        let capacity = Int(proc_listallpids(nil, 0))
        guard capacity > 0 else {
            return []
        }

        let pointer = UnsafeMutablePointer<pid_t>.allocate(capacity: capacity)
        defer { pointer.deallocate() }

        let bytesWritten = proc_listallpids(pointer, Int32(MemoryLayout<pid_t>.size * capacity))
        guard bytesWritten > 0 else {
            return []
        }

        let count = Int(bytesWritten)
        let buffer = UnsafeBufferPointer(start: pointer, count: count)
        return buffer.filter { $0 > 0 }
    }

    private func processInfo(for pid: pid_t) -> (ppid: pid_t, name: String)? {
        var info = proc_bsdinfo()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(
                pid,
                PROC_PIDTBSDINFO,
                0,
                pointer,
                Int32(MemoryLayout<proc_bsdinfo>.stride)
            )
        }

        guard result == Int32(MemoryLayout<proc_bsdinfo>.stride) else {
            return nil
        }

        let name = withUnsafePointer(to: info.pbi_name) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.pbi_name)) {
                String(cString: $0)
            }
        }

        return (ppid: pid_t(info.pbi_ppid), name: name)
    }

    private func residentMemorySample(for pid: pid_t) -> (bytes: UInt64, didSampleMemory: Bool) {
        var usage = rusage_info_v2()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_V2, reboundPointer)
            }
        }

        guard result == 0 else {
            return (0, false)
        }

        return (usage.ri_resident_size, true)
    }
}
