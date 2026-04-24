import SwiftUI

struct AlertPanelView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: AlertSessionController
    @Binding var settings: AppSettings
    @Binding var isIgnoringCurrentIncident: Bool
    let onSaveSettings: () -> Void

    private let snoozeDurationSeconds = 10 * 60.0

    private var language: AppLanguage? {
        settings.languageOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString("alert.title", language: language))
                    .font(.title3.weight(.semibold))

                Text(localizedFormat("alert.selection_count %lld", language: language, controller.state.selectedPIDs.count))
                    .foregroundStyle(.secondary)

                if controller.state.phase == .quitRequested {
                    ProgressView(
                        value: Double(progressCompletedSeconds),
                        total: Double(max(1, controller.state.countdownTotalSeconds))
                    )
                    .controlSize(.large)

                    Text(localizedFormat("alert.countdown %lld", language: language, controller.state.countdownRemaining))
                        .foregroundStyle(.secondary)
                } else if controller.state.phase == .forceQuitAvailable {
                    Text(localizedString("alert.force_quit_ready", language: language))
                        .foregroundStyle(.secondary)
                } else if let snoozeUntil = settings.snoozeUntil, snoozeUntil > Date() {
                    Text(
                        localizedFormat(
                            "alert.snoozed_until %@",
                            language: language,
                            snoozeUntil.formatted(date: .omitted, time: .shortened)
                        )
                    )
                    .foregroundStyle(.secondary)
                }
            }

            List(controller.state.visibleProcesses) { process in
                HStack(spacing: 12) {
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { controller.state.selectedPIDs.contains(process.pid) },
                            set: { controller.setSelected(pid: process.pid, isSelected: $0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(controller.state.isSelectionLocked)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(process.appName)
                            .font(.body.weight(.medium))
                        Text("PID \(process.pid)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(minWidth: 92, alignment: .trailing)

                    Toggle(
                        localizedString("alert.ignore_by_default", language: language),
                        isOn: Binding(
                            get: { isIgnoredByDefault(process) },
                            set: { setIgnoredByDefault(for: process, isIgnored: $0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(controller.state.isSelectionLocked || process.bundleIdentifier == nil)

                    Text(localizedString("alert.ignore_by_default", language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(
                        localizedString("alert.relaunch_after_quit", language: language),
                        isOn: Binding(
                            get: { controller.state.relaunchAfterQuitPIDs.contains(process.pid) },
                            set: { controller.setRelaunchAfterQuit(pid: process.pid, isEnabled: $0) }
                        )
                    )
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .disabled(
                        controller.state.isSelectionLocked ||
                        process.bundleIdentifier == nil ||
                        !controller.state.selectedPIDs.contains(process.pid)
                    )

                    Text(localizedString("alert.relaunch_after_quit", language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(controller.state.isSelectionLocked ? 0.6 : 1)
            }
            .overlay {
                if controller.state.visibleProcesses.isEmpty {
                    ContentUnavailableView(localizedString("alert.no_processes", language: language), systemImage: "checkmark.circle")
                }
            }

            HStack {
                Button(localizedString("alert.action.ignore_once", language: language)) {
                    isIgnoringCurrentIncident = true
                    controller.dismiss()
                    dismiss()
                }
                .disabled(controller.state.phase == .quitRequested)

                Button(localizedString("alert.action.snooze", language: language)) {
                    isIgnoringCurrentIncident = false
                    settings.snoozeUntil = Date().addingTimeInterval(snoozeDurationSeconds)
                    onSaveSettings()
                    controller.dismiss()
                    dismiss()
                }
                .disabled(controller.state.phase == .quitRequested)

                Spacer()

                Button(localizedString("alert.action.quit_selected", language: language)) {
                    Task {
                        await controller.requestQuitSelected()
                    }
                }
                .disabled(controller.state.isSelectionLocked || controller.state.selectedPIDs.isEmpty)

                if controller.state.phase == .forceQuitAvailable {
                    Button(localizedString("alert.action.force_quit_selected", language: language)) {
                        Task {
                            await controller.forceQuitSelected()
                        }
                    }
                    .disabled(controller.state.forceQuitPIDs.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 360)
        .task(id: controller.state.phase) {
            if controller.state.phase == .quitRequested {
                controller.startCountdown()
            }
        }
        .onChange(of: controller.state.phase) { _, phase in
            if phase == .completed || phase == .dismissed {
                dismiss()
            }
        }
        .onDisappear {
            if controller.state.phase != .completed {
                controller.dismiss()
            }
        }
    }

    private var countdownTotalSeconds: Int {
        max(controller.state.countdownTotalSeconds, 1)
    }

    private var progressCompletedSeconds: Int {
        max(0, countdownTotalSeconds - controller.state.countdownRemaining)
    }

    private func isIgnoredByDefault(_ process: ProcessSample) -> Bool {
        guard let bundleIdentifier = process.bundleIdentifier else {
            return false
        }
        return settings.ignoredBundleIdentifiers.contains(bundleIdentifier)
    }

    private func setIgnoredByDefault(for process: ProcessSample, isIgnored: Bool) {
        guard let bundleIdentifier = process.bundleIdentifier else {
            return
        }

        if isIgnored {
            if !settings.ignoredBundleIdentifiers.contains(bundleIdentifier) {
                settings.ignoredBundleIdentifiers.append(bundleIdentifier)
            }
            controller.setSelected(pid: process.pid, isSelected: false)
        } else {
            settings.ignoredBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        }

        settings.ignoredBundleIdentifiers.sort()
        onSaveSettings()
    }
}
