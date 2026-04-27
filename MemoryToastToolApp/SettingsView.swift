import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow

    @Binding var settings: AppSettings
    let onSave: () -> Void
    let onOpenAlert: () async -> Void

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        return formatter
    }()

    private let gigabyteFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private var language: AppLanguage? {
        settings.languageOverride
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button(localizedString("settings.action.open_alert", language: language)) {
                        Task {
                            await onOpenAlert()
                            openWindow(id: "memory-alert")
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(localizedString("settings.intro.title", language: language))
                        .font(.title2.weight(.semibold))
                    Text(localizedString("settings.intro.body", language: language))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Form {
                    Section {
                        TextField(localizedString("settings.interval", language: language), value: $settings.detectionIntervalSeconds, formatter: numberFormatter)
                        TextField(localizedString("settings.default_selected", language: language), value: $settings.defaultSelectedAppCount, formatter: numberFormatter)
                        TextField(localizedString("settings.relaunch_delay", language: language), value: $settings.relaunchDelaySeconds, formatter: numberFormatter)
                        TextField(localizedString("settings.force_quit_delay", language: language), value: $settings.forceQuitRevealDelaySeconds, formatter: numberFormatter)
                    }

                    Section(footer: Text(localizedString("settings.threshold_footer", language: language))) {
                        TextField(localizedString("settings.available_threshold", language: language), value: availableThresholdGigabytes, formatter: gigabyteFormatter)
                        TextField(localizedString("settings.swap_threshold", language: language), value: swapThresholdGigabytes, formatter: gigabyteFormatter)
                    }

                    Picker(localizedString("settings.language", language: language), selection: $settings.languageOverride) {
                        Text(localizedString("settings.language.system", language: language)).tag(AppLanguage?.none)
                        Text("English").tag(AppLanguage?.some(.english))
                        Text("简体中文").tag(AppLanguage?.some(.simplifiedChinese))
                    }

                    Section(localizedString("settings.ignored_apps", language: language)) {
                        if settings.ignoredBundleIdentifiers.isEmpty {
                            Text(localizedString("settings.ignored_none", language: language))
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(settings.ignoredBundleIdentifiers, id: \.self) { bundleIdentifier in
                                Text(bundleIdentifier)
                                    .font(.footnote)
                            }
                        }
                    }

                    if settings.snoozeUntil != nil {
                        Button(localizedString("settings.clear_snooze", language: language)) {
                            settings.snoozeUntil = nil
                            onSave()
                        }
                    }

                    Button(localizedString("settings.save", language: language), action: onSave)
                }
            }
            .padding(20)
        }
        .frame(width: 520, height: 620)
    }

    private var availableThresholdGigabytes: Binding<Double> {
        Binding(
            get: {
                bytesToGigabytes(settings.availableMemoryAlertThresholdBytes)
            },
            set: { newValue in
                settings.availableMemoryAlertThresholdBytes = gigabytesToBytes(newValue)
            }
        )
    }

    private var swapThresholdGigabytes: Binding<Double> {
        Binding(
            get: {
                bytesToGigabytes(settings.swapUsedAlertThresholdBytes)
            },
            set: { newValue in
                settings.swapUsedAlertThresholdBytes = gigabytesToBytes(newValue)
            }
        )
    }

    private func bytesToGigabytes(_ bytes: UInt64) -> Double {
        Double(bytes) / Double(AppSettings.bytesPerGigabyte)
    }

    private func gigabytesToBytes(_ gigabytes: Double) -> UInt64 {
        UInt64(max(0, gigabytes) * Double(AppSettings.bytesPerGigabyte))
    }
}
