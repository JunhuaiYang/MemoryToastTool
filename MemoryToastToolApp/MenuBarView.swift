import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    let settings: AppSettings
    let onRefresh: () -> Void
    let onOpenAlert: () -> Void
    let onOpenGuide: () -> Void

    private var language: AppLanguage? {
        settings.languageOverride
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localizedString("menu.title", language: language))
                .font(.headline)

            Text(localizedPressureLevel(viewModel.statusLevel, language: language))
                .foregroundStyle(.secondary)

            if let snapshot = viewModel.latestSnapshot {
                metricGrid(snapshot: snapshot)
            } else {
                Text(localizedString("menu.loading", language: language))
                    .foregroundStyle(.secondary)
            }

            if !viewModel.latestReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedString("menu.reasons", language: language))
                        .font(.subheadline.weight(.semibold))

                    ForEach(Array(viewModel.latestReasons.enumerated()), id: \.offset) { _, reason in
                        Text(localizedRuleReason(reason, language: language))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(localizedString("menu.top_apps", language: language))
                    .font(.subheadline.weight(.semibold))

                if viewModel.topProcesses.isEmpty {
                    Text(localizedString("menu.no_apps", language: language))
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                } else {
                    ForEach(viewModel.topProcesses) { process in
                        HStack {
                            Text(process.appName)
                                .lineLimit(1)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote)
                    }
                }
            }

            Divider()

            HStack {
                Button(localizedString("menu.action.run_check", language: language), action: onRefresh)
                Button(localizedString("menu.action.open_alert", language: language), action: onOpenAlert)
            }

            Button(localizedString("menu.action.open_guide", language: language), action: onOpenGuide)

            Text(localizedFormat("menu.interval %lld", language: language, settings.detectionIntervalSeconds))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder
    private func metricGrid(snapshot: MemorySnapshot) -> some View {
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
        }
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
