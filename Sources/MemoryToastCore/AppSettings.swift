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
    public var languageOverride: AppLanguage?

    public static let defaultValue = AppSettings(
        detectionIntervalSeconds: 30,
        defaultSelectedAppCount: 3,
        relaunchDelaySeconds: 5,
        forceQuitRevealDelaySeconds: 10,
        languageOverride: nil
    )

    public init(
        detectionIntervalSeconds: Int,
        defaultSelectedAppCount: Int,
        relaunchDelaySeconds: Int,
        forceQuitRevealDelaySeconds: Int,
        languageOverride: AppLanguage?
    ) {
        self.detectionIntervalSeconds = detectionIntervalSeconds
        self.defaultSelectedAppCount = defaultSelectedAppCount
        self.relaunchDelaySeconds = relaunchDelaySeconds
        self.forceQuitRevealDelaySeconds = forceQuitRevealDelaySeconds
        self.languageOverride = languageOverride
    }
}
