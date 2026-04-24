import Darwin
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
        let totalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let vmStats = virtualMemoryStatistics()
        let availableMemoryBytes = min(totalMemoryBytes, availableMemoryBytes(from: vmStats))
        let usedMemoryBytes = totalMemoryBytes > availableMemoryBytes ? totalMemoryBytes - availableMemoryBytes : 0
        let swapUsedBytes = currentSwapUsageBytes()
        let pressureLevel = pressureLevel(
            totalMemoryBytes: totalMemoryBytes,
            availableMemoryBytes: availableMemoryBytes,
            swapUsedBytes: swapUsedBytes
        )

        return SystemMemorySample(
            totalMemoryBytes: totalMemoryBytes,
            usedMemoryBytes: usedMemoryBytes,
            availableMemoryBytes: availableMemoryBytes,
            swapUsedBytes: swapUsedBytes,
            pressureLevel: pressureLevel
        )
    }

    private func virtualMemoryStatistics() -> vm_statistics64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPointer, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return vm_statistics64()
        }

        return stats
    }

    private func availableMemoryBytes(from stats: vm_statistics64) -> UInt64 {
        let pageSize = UInt64(kernelPageSize())
        let reclaimablePages = UInt64(stats.free_count) + UInt64(stats.inactive_count) + UInt64(stats.speculative_count)
        return reclaimablePages * pageSize
    }

    private func kernelPageSize() -> vm_size_t {
        var pageSize: vm_size_t = 0
        let result = host_page_size(mach_host_self(), &pageSize)
        guard result == KERN_SUCCESS else {
            return vm_size_t(getpagesize())
        }
        return pageSize
    }

    private func currentSwapUsageBytes() -> UInt64 {
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.stride
        let result = sysctlbyname("vm.swapusage", &swap, &size, nil, 0)
        guard result == 0 else {
            return 0
        }
        return swap.xsu_used
    }

    private func pressureLevel(
        totalMemoryBytes: UInt64,
        availableMemoryBytes: UInt64,
        swapUsedBytes: UInt64
    ) -> MemoryPressureLevel {
        guard totalMemoryBytes > 0 else {
            return .normal
        }

        let availableRatio = Double(availableMemoryBytes) / Double(totalMemoryBytes)
        if availableRatio < 0.05 || swapUsedBytes > 4_000_000_000 {
            return .critical
        }
        if availableRatio < 0.10 || swapUsedBytes > 1_000_000_000 {
            return .warning
        }
        return .normal
    }
}
