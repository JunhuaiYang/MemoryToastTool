import Foundation

public struct AlertPresentationPolicy: Sendable {
    public init() {}

    public func shouldPresentAlert(
        triggerReasons: [String],
        isAlertActive: Bool,
        isIgnoringCurrentIncident: Bool,
        snoozeUntil: Date?,
        now: Date
    ) -> Bool {
        guard !triggerReasons.isEmpty else {
            return false
        }
        guard !isAlertActive else {
            return false
        }
        guard !isIgnoringCurrentIncident else {
            return false
        }
        if let snoozeUntil, now < snoozeUntil {
            return false
        }
        return true
    }

    public func shouldKeepIgnoringCurrentIncident(
        isIgnoringCurrentIncident: Bool,
        triggerReasons: [String]
    ) -> Bool {
        guard isIgnoringCurrentIncident else {
            return false
        }
        return !triggerReasons.isEmpty
    }
}
