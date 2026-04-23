import Foundation

public protocol ProcessSampling: Sendable {
    func sampleProcesses() async throws -> [ProcessSample]
}

public struct LiveProcessSampler: ProcessSampling {
    public init() {}

    public func sampleProcesses() async throws -> [ProcessSample] {
        []
    }
}
