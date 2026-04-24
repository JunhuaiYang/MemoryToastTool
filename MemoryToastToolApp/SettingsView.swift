import SwiftUI

struct SettingsView: View {
    @Binding var settings: AppSettings
    let onSave: () -> Void

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        return formatter
    }()

    var body: some View {
        Form {
            TextField(String(localized: "settings.interval"), value: $settings.detectionIntervalSeconds, formatter: numberFormatter)
            TextField(String(localized: "settings.default_selected"), value: $settings.defaultSelectedAppCount, formatter: numberFormatter)
            TextField(String(localized: "settings.relaunch_delay"), value: $settings.relaunchDelaySeconds, formatter: numberFormatter)
            TextField(String(localized: "settings.force_quit_delay"), value: $settings.forceQuitRevealDelaySeconds, formatter: numberFormatter)
            TextField(String(localized: "settings.available_threshold"), value: $settings.availableMemoryAlertThresholdBytes, formatter: numberFormatter)
            TextField(String(localized: "settings.swap_threshold"), value: $settings.swapUsedAlertThresholdBytes, formatter: numberFormatter)

            Picker(String(localized: "settings.language"), selection: $settings.languageOverride) {
                Text(String(localized: "settings.language.system")).tag(AppLanguage?.none)
                Text("English").tag(AppLanguage?.some(.english))
                Text("简体中文").tag(AppLanguage?.some(.simplifiedChinese))
            }

            Button(String(localized: "settings.save"), action: onSave)
        }
        .padding(20)
        .frame(width: 420)
    }
}
