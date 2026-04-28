import Foundation

public enum MonitoringCadence {
    public static func refreshIntervalSeconds(detectionIntervalSeconds: Int, isAlertActive: Bool) -> Int {
        if isAlertActive {
            return 1
        }

        return max(1, detectionIntervalSeconds)
    }
}
