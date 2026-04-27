import XCTest
@testable import MemoryToastCore

final class SettingsStoreTests: XCTestCase {
    func testDefaultSettingsMatchProductSpec() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(defaults: defaults)

        let settings = store.load()

        XCTAssertEqual(settings.detectionIntervalSeconds, 30)
        XCTAssertEqual(settings.defaultSelectedAppCount, 3)
        XCTAssertEqual(settings.relaunchDelaySeconds, 5)
        XCTAssertEqual(settings.forceQuitRevealDelaySeconds, 10)
        XCTAssertEqual(settings.availableMemoryAlertThresholdBytes, 2_000_000_000)
        XCTAssertEqual(settings.swapUsedAlertThresholdBytes, 4_000_000_000)
        XCTAssertTrue(settings.ignoredBundleIdentifiers.isEmpty)
        XCTAssertNil(settings.snoozeUntil)
        XCTAssertNil(settings.languageOverride)
    }

    func testSaveRoundTripPersistsValues() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(defaults: defaults)

        var settings = AppSettings.defaultValue
        settings.detectionIntervalSeconds = 12
        settings.defaultSelectedAppCount = 4
        settings.relaunchDelaySeconds = 9
        settings.forceQuitRevealDelaySeconds = 11
        settings.availableMemoryAlertThresholdBytes = 1_200_000_000
        settings.swapUsedAlertThresholdBytes = 6_000_000_000
        settings.ignoredBundleIdentifiers = ["com.apple.Safari", "com.tinyspeck.slackmacgap"]
        settings.snoozeUntil = Date(timeIntervalSince1970: 1_234_567)
        settings.languageOverride = .english

        store.save(settings)

        let reloaded = store.load()

        XCTAssertEqual(reloaded.detectionIntervalSeconds, 12)
        XCTAssertEqual(reloaded.defaultSelectedAppCount, 4)
        XCTAssertEqual(reloaded.relaunchDelaySeconds, 9)
        XCTAssertEqual(reloaded.forceQuitRevealDelaySeconds, 11)
        XCTAssertEqual(reloaded.availableMemoryAlertThresholdBytes, 1_200_000_000)
        XCTAssertEqual(reloaded.swapUsedAlertThresholdBytes, 6_000_000_000)
        XCTAssertEqual(reloaded.ignoredBundleIdentifiers, ["com.apple.Safari", "com.tinyspeck.slackmacgap"])
        XCTAssertEqual(reloaded.snoozeUntil, Date(timeIntervalSince1970: 1_234_567))
        XCTAssertEqual(reloaded.languageOverride, .english)
    }

    func testLoadIgnoresLegacySafetyGuideFlag() throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(defaults: defaults)
        defaults.set(
            try XCTUnwrap(
                """
                {
                  "detectionIntervalSeconds": 15,
                  "defaultSelectedAppCount": 2,
                  "relaunchDelaySeconds": 7,
                  "forceQuitRevealDelaySeconds": 9,
                  "availableMemoryAlertThresholdBytes": 3000000000,
                  "swapUsedAlertThresholdBytes": 5000000000,
                  "ignoredBundleIdentifiers": ["com.apple.Safari"],
                  "snoozeUntil": 1234567,
                  "hasAcknowledgedSafetyGuide": true,
                  "languageOverride": "zh-Hans"
                }
                """.data(using: .utf8)
            ),
            forKey: "app_settings"
        )

        let loaded = store.load()

        XCTAssertEqual(loaded.detectionIntervalSeconds, 15)
        XCTAssertEqual(loaded.defaultSelectedAppCount, 2)
        XCTAssertEqual(loaded.relaunchDelaySeconds, 7)
        XCTAssertEqual(loaded.forceQuitRevealDelaySeconds, 9)
        XCTAssertEqual(loaded.availableMemoryAlertThresholdBytes, 3_000_000_000)
        XCTAssertEqual(loaded.swapUsedAlertThresholdBytes, 5_000_000_000)
        XCTAssertEqual(loaded.ignoredBundleIdentifiers, ["com.apple.Safari"])
        XCTAssertEqual(loaded.snoozeUntil, Date(timeIntervalSinceReferenceDate: 1_234_567))
        XCTAssertEqual(loaded.languageOverride, .simplifiedChinese)
    }
}
