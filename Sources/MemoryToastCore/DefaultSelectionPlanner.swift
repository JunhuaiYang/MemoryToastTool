import Foundation

public struct DefaultSelectionPlanner: Sendable {
    public init() {}

    public func selectDefaultPIDs(
        from processes: [ProcessSample],
        count: Int,
        ignoredBundleIdentifiers: [String]
    ) -> [Int32] {
        guard count > 0 else {
            return []
        }

        let ignored = Set(ignoredBundleIdentifiers)
        return processes
            .filter { process in
                guard let bundleIdentifier = process.bundleIdentifier else {
                    return true
                }
                return !ignored.contains(bundleIdentifier)
            }
            .prefix(count)
            .map(\.pid)
    }
}
