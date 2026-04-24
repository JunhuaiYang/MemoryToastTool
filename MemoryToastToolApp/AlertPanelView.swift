import SwiftUI

struct AlertPanelView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: AlertSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "alert.title"))
                    .font(.title3.weight(.semibold))

                Text(String(format: String(localized: "alert.selection_count %lld"), controller.state.selectedPIDs.count))
                    .foregroundStyle(.secondary)

                if controller.state.phase == .quitRequested {
                    ProgressView(
                        value: Double(progressCompletedSeconds),
                        total: Double(max(1, controller.state.countdownTotalSeconds))
                    )
                    .controlSize(.large)

                    Text(String(format: String(localized: "alert.countdown %lld"), controller.state.countdownRemaining))
                        .foregroundStyle(.secondary)
                } else if controller.state.phase == .forceQuitAvailable {
                    Text(String(localized: "alert.force_quit_ready"))
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

                    Toggle(
                        String(localized: "alert.relaunch_after_quit"),
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

                    Text(String(localized: "alert.relaunch_after_quit"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .opacity(controller.state.isSelectionLocked ? 0.6 : 1)
            }
            .overlay {
                if controller.state.visibleProcesses.isEmpty {
                    ContentUnavailableView(String(localized: "alert.no_processes"), systemImage: "checkmark.circle")
                }
            }

            HStack {
                Button(String(localized: "alert.action.quit_selected")) {
                    Task {
                        await controller.requestQuitSelected()
                    }
                }
                .disabled(controller.state.isSelectionLocked || controller.state.selectedPIDs.isEmpty)

                if controller.state.phase == .forceQuitAvailable {
                    Button(String(localized: "alert.action.force_quit_selected")) {
                        Task {
                            await controller.forceQuitSelected()
                        }
                    }
                    .disabled(controller.state.forceQuitPIDs.isEmpty)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
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
}
