import Darwin
import XCTest
@testable import MemoryToastCore

final class ProcessSamplingTests: XCTestCase {
    func testProcessMemorySampleUsesPhysicalFootprint() {
        var usage = rusage_info_v2()
        usage.ri_resident_size = 1_024
        usage.ri_phys_footprint = 4_096

        let sample = ProcessMemorySample.make(from: usage, result: 0)

        XCTAssertEqual(sample.bytes, 4_096)
        XCTAssertTrue(sample.didSampleMemory)
    }

    func testProcessMemorySampleReportsFailureWhenKernelCallFails() {
        var usage = rusage_info_v2()
        usage.ri_phys_footprint = 4_096

        let sample = ProcessMemorySample.make(from: usage, result: -1)

        XCTAssertEqual(sample.bytes, 0)
        XCTAssertFalse(sample.didSampleMemory)
    }
}
