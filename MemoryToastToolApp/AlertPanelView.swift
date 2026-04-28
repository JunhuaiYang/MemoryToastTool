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
            headerSection

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if controller.state.visibleTreeRoots.isEmpty {
                        ContentUnavailableView(localizedString("alert.no_processes", language: language), systemImage: "checkmark.circle")
                    } else {
                        ForEach(controller.state.visibleTreeRoots) { root in
                            ProcessTreeRow(
                                node: root,
                                depth: 0,
                                controller: controller,
                                settings: $settings,
                                language: language,
                                onSaveSettings: onSaveSettings
                            )
                        }
                    }
                }
            }

            actionBar
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 420)
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
        .alert(
            localizedString("alert.force_quit_prompt.title", language: language),
            isPresented: forceQuitConfirmationBinding
        ) {
            Button(localizedString("alert.action.continue_waiting", language: language), role: .cancel) {
                controller.continueWaitingAfterForceQuitPrompt()
            }

            Button(localizedString("alert.action.force_quit_selected", language: language), role: .destructive) {
                Task {
                    await controller.forceQuitSelected()
                }
            }
        } message: {
            Text(localizedFormat("alert.force_quit_prompt.message %lld", language: language, controller.state.forceQuitPIDs.count))
        }
        .onDisappear {
            if controller.state.phase != .completed {
                controller.dismiss()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedString("alert.title", language: language))
                .font(.title3.weight(.semibold))

            Text(localizedFormat("alert.selection_count %lld", language: language, controller.state.selectedPIDs.count))
                .foregroundStyle(.secondary)

            if let snapshot = controller.state.snapshot {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        metricCell(
                            title: localizedString("menu.metric.used", language: language),
                            value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.usedMemoryBytes), countStyle: .memory)
                        )
                        metricCell(
                            title: localizedString("menu.metric.available", language: language),
                            value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.availableMemoryBytes), countStyle: .memory)
                        )
                    }
                    GridRow {
                        metricCell(
                            title: localizedString("menu.metric.swap", language: language),
                            value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.swapUsedBytes), countStyle: .memory)
                        )
                        metricCell(
                            title: localizedString("menu.metric.pressure", language: language),
                            value: localizedPressureLevel(snapshot.pressureLevel, language: language)
                        )
                    }
                    GridRow {
                        metricCell(
                            title: localizedString("alert.metric.process_tree_total", language: language),
                            value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.processTreeMemoryBytes), countStyle: .memory)
                        )
                        metricCell(
                            title: localizedString("alert.metric.unattributed_memory", language: language),
                            value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.unattributedMemoryBytes), countStyle: .memory)
                        )
                    }
                }

                if snapshot.failedProcessMemorySampleCount > 0 {
                    Text(
                        localizedFormat(
                            "alert.memory_sampling_failures %lld",
                            language: language,
                            snapshot.failedProcessMemorySampleCount
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }

            if !controller.state.matchedReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("menu.reasons", language: language))
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(controller.state.matchedReasons.enumerated()), id: \.offset) { _, reason in
                        Text(localizedRuleReason(reason, language: language))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if controller.state.phase == .quitRequested {
                ProgressView(
                    value: Double(progressCompletedSeconds),
                    total: Double(max(1, controller.state.countdownTotalSeconds))
                )
                .controlSize(.large)

                Text(localizedFormat("alert.countdown %lld", language: language, controller.state.countdownRemaining))
                    .foregroundStyle(.secondary)
            } else if controller.state.phase == .waitingForQuitCompletion {
                Text(localizedString("alert.waiting_for_exit", language: language))
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
    }

    private var actionBar: some View {
        HStack {
            Button(localizedString("alert.action.ignore_once", language: language)) {
                isIgnoringCurrentIncident = true
                controller.dismiss()
                dismiss()
            }
            .disabled(controller.state.isSelectionLocked)

            Button(localizedString("alert.action.snooze", language: language)) {
                isIgnoringCurrentIncident = false
                settings.snoozeUntil = Date().addingTimeInterval(snoozeDurationSeconds)
                onSaveSettings()
                controller.dismiss()
                dismiss()
            }
            .disabled(controller.state.isSelectionLocked)

            Spacer()

            Button(localizedString("alert.action.quit_selected", language: language)) {
                Task {
                    await controller.requestQuitSelected()
                }
            }
            .disabled(controller.state.isSelectionLocked || controller.state.selectedPIDs.isEmpty)
        }
    }

    private var countdownTotalSeconds: Int {
        max(controller.state.countdownTotalSeconds, 1)
    }

    private var progressCompletedSeconds: Int {
        max(0, countdownTotalSeconds - controller.state.countdownRemaining)
    }

    private var forceQuitConfirmationBinding: Binding<Bool> {
        Binding(
            get: { controller.state.isForceQuitConfirmationPresented },
            set: { isPresented in
                if !isPresented {
                    controller.continueWaitingAfterForceQuitPrompt()
                }
            }
        )
    }

    @ViewBuilder
    private func metricCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProcessTreeRow: View {
    let node: ProcessTreeNode
    let depth: Int
    @ObservedObject var controller: AlertSessionController
    @Binding var settings: AppSettings
    let language: AppLanguage?
    let onSaveSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                expandButton
                selectionButton

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.processName)
                        .font(.body.weight(.medium))
                    Text("PID \(node.pid)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(displayedMemory)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 92, alignment: .trailing)

                Toggle(
                    localizedString("alert.ignore_by_default", language: language),
                    isOn: Binding(
                        get: { isIgnoredByDefault },
                        set: { setIgnoredByDefault($0) }
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(controller.state.isSelectionLocked || node.bundleIdentifier == nil)

                Toggle(
                    localizedString("alert.relaunch_after_quit", language: language),
                    isOn: Binding(
                        get: { controller.state.relaunchAfterQuitPIDs.contains(node.pid) },
                        set: { controller.setRelaunchAfterQuit(pid: node.pid, isEnabled: $0) }
                    )
                )
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(
                    controller.state.isSelectionLocked ||
                    node.bundleIdentifier == nil ||
                    !controller.state.selectedPIDs.contains(node.pid)
                )
            }
            .padding(.leading, CGFloat(depth) * 18)
            .opacity(controller.state.isSelectionLocked ? 0.6 : 1)

            if controller.isExpanded(pid: node.pid) {
                ForEach(node.children) { child in
                    ProcessTreeRow(
                        node: child,
                        depth: depth + 1,
                        controller: controller,
                        settings: $settings,
                        language: language,
                        onSaveSettings: onSaveSettings
                    )
                }
            }
        }
    }

    private var displayedMemory: String {
        let bytes = depth == 0 ? node.aggregateMemoryBytes : node.memoryBytes
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }

    private var expandButton: some View {
        Group {
            if node.children.isEmpty {
                Color.clear
                    .frame(width: 14, height: 14)
            } else {
                Button {
                    controller.toggleExpanded(pid: node.pid)
                } label: {
                    Image(systemName: controller.isExpanded(pid: node.pid) ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .frame(width: 14, height: 14)
            }
        }
    }

    private var selectionButton: some View {
        Button {
            let nextSelected = controller.selectionState(for: node.pid) != .selected
            controller.setSelected(pid: node.pid, isSelected: nextSelected)
        } label: {
            Image(systemName: selectionImageName)
                .font(.body)
        }
        .buttonStyle(.plain)
        .disabled(controller.state.isSelectionLocked)
    }

    private var selectionImageName: String {
        switch controller.selectionState(for: node.pid) {
        case .unselected:
            return "square"
        case .selected:
            return "checkmark.square.fill"
        case .partiallySelected:
            return "minus.square.fill"
        }
    }

    private var isIgnoredByDefault: Bool {
        guard let bundleIdentifier = node.bundleIdentifier else {
            return false
        }
        return settings.ignoredBundleIdentifiers.contains(bundleIdentifier)
    }

    private func setIgnoredByDefault(_ isIgnored: Bool) {
        guard let bundleIdentifier = node.bundleIdentifier else {
            return
        }

        if isIgnored {
            if !settings.ignoredBundleIdentifiers.contains(bundleIdentifier) {
                settings.ignoredBundleIdentifiers.append(bundleIdentifier)
            }
            controller.setSelected(pid: node.pid, isSelected: false)
        } else {
            settings.ignoredBundleIdentifiers.removeAll { $0 == bundleIdentifier }
        }

        settings.ignoredBundleIdentifiers.sort()
        onSaveSettings()
    }
}
