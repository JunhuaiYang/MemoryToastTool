import Darwin
import Foundation

struct ProcessMemorySample {
    let bytes: UInt64
    let didSampleMemory: Bool

    static func make(from usage: rusage_info_v2, result: Int32) -> ProcessMemorySample {
        guard result == 0 else {
            return ProcessMemorySample(bytes: 0, didSampleMemory: false)
        }

        return ProcessMemorySample(bytes: usage.ri_phys_footprint, didSampleMemory: true)
    }
}
