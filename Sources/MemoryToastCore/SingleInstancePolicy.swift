import Foundation

public enum SingleInstanceDecision: Equatable, Sendable {
    case continueLaunching
    case activateExistingAndTerminateCurrent(existingProcessIdentifier: Int32)
}

public struct SingleInstancePolicy: Sendable {
    public init() {}

    public func decision(
        bundleIdentifier: String?,
        currentProcessIdentifier: Int32,
        runningProcessIdentifiers: [Int32]
    ) -> SingleInstanceDecision {
        guard
            let bundleIdentifier,
            !bundleIdentifier.isEmpty,
            let existingProcessIdentifier = runningProcessIdentifiers.first(where: { $0 != currentProcessIdentifier })
        else {
            return .continueLaunching
        }

        _ = bundleIdentifier
        return .activateExistingAndTerminateCurrent(existingProcessIdentifier: existingProcessIdentifier)
    }
}
