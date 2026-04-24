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
        settings.languageOverride = .english

        store.save(settings)

        let reloaded = store.load()

        XCTAssertEqual(reloaded.detectionIntervalSeconds, 12)
        XCTAssertEqual(reloaded.defaultSelectedAppCount, 4)
        XCTAssertEqual(reloaded.relaunchDelaySeconds, 9)
        XCTAssertEqual(reloaded.forceQuitRevealDelaySeconds, 11)
        XCTAssertEqual(reloaded.availableMemoryAlertThresholdBytes, 1_200_000_000)
        XCTAssertEqual(reloaded.swapUsedAlertThresholdBytes, 6_000_000_000)
        XCTAssertEqual(reloaded.languageOverride, .english)
    }
}
