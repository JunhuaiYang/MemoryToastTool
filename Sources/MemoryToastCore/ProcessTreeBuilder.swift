import Foundation

public struct ProcessTreeBuilder: Sendable {
    public let systemRootNames: Set<String>

    public init(systemRootNames: Set<String> = ["launchd", "kernel_task"]) {
        self.systemRootNames = systemRootNames
    }

    public func buildTree(from processes: [RawProcessSample]) -> [ProcessTreeNode] {
        let liveProcesses = processes.filter(\.isRunning)
        let processByPID = Dictionary(uniqueKeysWithValues: liveProcesses.map { ($0.pid, $0) })
        let childPIDsByParent = Dictionary(grouping: liveProcesses, by: \.ppid)
            .mapValues { samples in
                samples.map(\.pid).sorted()
            }

        let rootPIDs = liveProcesses
            .filter { sample in
                guard !systemRootNames.contains(sample.processName) else {
                    return false
                }

                guard let parent = processByPID[sample.ppid] else {
                    return true
                }

                return systemRootNames.contains(parent.processName)
            }
            .map(\.pid)

        return rootPIDs.compactMap { pid in
            makeNode(
                pid: pid,
                parentPID: nil,
                processByPID: processByPID,
                childPIDsByParent: childPIDsByParent
            )
        }
        .sorted { lhs, rhs in
            if lhs.aggregateMemoryBytes == rhs.aggregateMemoryBytes {
                return lhs.pid < rhs.pid
            }
            return lhs.aggregateMemoryBytes > rhs.aggregateMemoryBytes
        }
    }

    private func makeNode(
        pid: Int32,
        parentPID: Int32?,
        processByPID: [Int32: RawProcessSample],
        childPIDsByParent: [Int32: [Int32]]
    ) -> ProcessTreeNode? {
        guard let sample = processByPID[pid] else {
            return nil
        }

        let children = (childPIDsByParent[pid] ?? []).compactMap { childPID in
            makeNode(
                pid: childPID,
                parentPID: pid,
                processByPID: processByPID,
                childPIDsByParent: childPIDsByParent
            )
        }

        let aggregateMemoryBytes = sample.memoryBytes + children.reduce(0) { partialResult, child in
            partialResult + child.aggregateMemoryBytes
        }

        return ProcessTreeNode(
            pid: sample.pid,
            parentPID: parentPID,
            processName: sample.processName,
            bundleIdentifier: sample.bundleIdentifier,
            memoryBytes: sample.memoryBytes,
            aggregateMemoryBytes: aggregateMemoryBytes,
            isRunning: sample.isRunning,
            children: children
        )
    }
}
