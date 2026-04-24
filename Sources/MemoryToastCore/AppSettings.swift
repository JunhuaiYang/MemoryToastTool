import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var detectionIntervalSeconds: Int
    public var defaultSelectedAppCount: Int
    public var relaunchDelaySeconds: Int
    public var forceQuitRevealDelaySeconds: Int
    public var availableMemoryAlertThresholdBytes: UInt64
    public var swapUsedAlertThresholdBytes: UInt64
    public var ignoredBundleIdentifiers: [String]
    public var snoozeUntil: Date?
    public var languageOverride: AppLanguage?

    public static let defaultValue = AppSettings(
        detectionIntervalSeconds: 30,
        defaultSelectedAppCount: 3,
        relaunchDelaySeconds: 5,
        forceQuitRevealDelaySeconds: 10,
        availableMemoryAlertThresholdBytes: 2_000_000_000,
        swapUsedAlertThresholdBytes: 4_000_000_000,
        ignoredBundleIdentifiers: [],
        snoozeUntil: nil,
        languageOverride: nil
    )

    public init(
        detectionIntervalSeconds: Int,
        defaultSelectedAppCount: Int,
        relaunchDelaySeconds: Int,
        forceQuitRevealDelaySeconds: Int,
        availableMemoryAlertThresholdBytes: UInt64,
        swapUsedAlertThresholdBytes: UInt64,
        ignoredBundleIdentifiers: [String],
        snoozeUntil: Date?,
        languageOverride: AppLanguage?
    ) {
        self.detectionIntervalSeconds = detectionIntervalSeconds
        self.defaultSelectedAppCount = defaultSelectedAppCount
        self.relaunchDelaySeconds = relaunchDelaySeconds
        self.forceQuitRevealDelaySeconds = forceQuitRevealDelaySeconds
        self.availableMemoryAlertThresholdBytes = availableMemoryAlertThresholdBytes
        self.swapUsedAlertThresholdBytes = swapUsedAlertThresholdBytes
        self.ignoredBundleIdentifiers = ignoredBundleIdentifiers
        self.snoozeUntil = snoozeUntil
        self.languageOverride = languageOverride
    }
}
