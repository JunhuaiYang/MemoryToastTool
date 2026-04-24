import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    let settings: AppSettings
    let onRefresh: () -> Void
    let onOpenAlert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "menu.title"))
                .font(.headline)

            Text(viewModel.statusText)
                .foregroundStyle(.secondary)

            if let snapshot = viewModel.latestSnapshot {
                metricGrid(snapshot: snapshot)
            } else {
                Text(String(localized: "menu.loading"))
                    .foregroundStyle(.secondary)
            }

            if !viewModel.latestReasons.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "menu.reasons"))
                        .font(.subheadline.weight(.semibold))

                    ForEach(viewModel.latestReasons, id: \.self) { reason in
                        Text(reason)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "menu.top_apps"))
                    .font(.subheadline.weight(.semibold))

                if viewModel.topProcesses.isEmpty {
                    Text(String(localized: "menu.no_apps"))
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
                Button(String(localized: "menu.action.run_check"), action: onRefresh)
                Button(String(localized: "menu.action.open_alert"), action: onOpenAlert)
            }

            Text(String(format: String(localized: "menu.interval %lld"), settings.detectionIntervalSeconds))
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
                metricCell(title: String(localized: "menu.metric.used"), value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.usedMemoryBytes), countStyle: .memory))
                metricCell(title: String(localized: "menu.metric.available"), value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.availableMemoryBytes), countStyle: .memory))
            }
            GridRow {
                metricCell(title: String(localized: "menu.metric.swap"), value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.swapUsedBytes), countStyle: .memory))
                metricCell(title: String(localized: "menu.metric.pressure"), value: snapshot.pressureLevel.rawValue.capitalized)
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
