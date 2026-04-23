import Foundation

public final class SettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let settingsKey = "app_settings"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: settingsKey),
            let settings = try? decoder.decode(AppSettings.self, from: data)
        else {
            return .defaultValue
        }

        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else {
            return
        }

        defaults.set(data, forKey: settingsKey)
    }
}
