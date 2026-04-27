import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}

public struct AppSettings: Codable, Equatable, Sendable {
    public static let bytesPerGigabyte: UInt64 = 1_000_000_000

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
        availableMemoryAlertThresholdBytes: 2 * bytesPerGigabyte,
        swapUsedAlertThresholdBytes: 4 * bytesPerGigabyte,
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

    enum CodingKeys: String, CodingKey {
        case detectionIntervalSeconds
        case defaultSelectedAppCount
        case relaunchDelaySeconds
        case forceQuitRevealDelaySeconds
        case availableMemoryAlertThresholdBytes
        case swapUsedAlertThresholdBytes
        case ignoredBundleIdentifiers
        case snoozeUntil
        case languageOverride
        case hasAcknowledgedSafetyGuide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        detectionIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .detectionIntervalSeconds) ?? Self.defaultValue.detectionIntervalSeconds
        defaultSelectedAppCount = try container.decodeIfPresent(Int.self, forKey: .defaultSelectedAppCount) ?? Self.defaultValue.defaultSelectedAppCount
        relaunchDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .relaunchDelaySeconds) ?? Self.defaultValue.relaunchDelaySeconds
        forceQuitRevealDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .forceQuitRevealDelaySeconds) ?? Self.defaultValue.forceQuitRevealDelaySeconds
        availableMemoryAlertThresholdBytes = try container.decodeIfPresent(UInt64.self, forKey: .availableMemoryAlertThresholdBytes) ?? Self.defaultValue.availableMemoryAlertThresholdBytes
        swapUsedAlertThresholdBytes = try container.decodeIfPresent(UInt64.self, forKey: .swapUsedAlertThresholdBytes) ?? Self.defaultValue.swapUsedAlertThresholdBytes
        ignoredBundleIdentifiers = try container.decodeIfPresent([String].self, forKey: .ignoredBundleIdentifiers) ?? Self.defaultValue.ignoredBundleIdentifiers
        snoozeUntil = try container.decodeIfPresent(Date.self, forKey: .snoozeUntil)
        languageOverride = try container.decodeIfPresent(AppLanguage.self, forKey: .languageOverride)

        _ = try container.decodeIfPresent(Bool.self, forKey: .hasAcknowledgedSafetyGuide)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(detectionIntervalSeconds, forKey: .detectionIntervalSeconds)
        try container.encode(defaultSelectedAppCount, forKey: .defaultSelectedAppCount)
        try container.encode(relaunchDelaySeconds, forKey: .relaunchDelaySeconds)
        try container.encode(forceQuitRevealDelaySeconds, forKey: .forceQuitRevealDelaySeconds)
        try container.encode(availableMemoryAlertThresholdBytes, forKey: .availableMemoryAlertThresholdBytes)
        try container.encode(swapUsedAlertThresholdBytes, forKey: .swapUsedAlertThresholdBytes)
        try container.encode(ignoredBundleIdentifiers, forKey: .ignoredBundleIdentifiers)
        try container.encodeIfPresent(snoozeUntil, forKey: .snoozeUntil)
        try container.encodeIfPresent(languageOverride, forKey: .languageOverride)
    }
}
