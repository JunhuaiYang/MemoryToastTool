import SwiftUI

struct MenuBarContainerView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var alertSessionController: AlertSessionController
    @Binding var settings: AppSettings
    @Binding var isIgnoringCurrentIncident: Bool

    private let selectionPlanner = DefaultSelectionPlanner()
    private let presentationPolicy = AlertPresentationPolicy()

    var body: some View {
        MenuBarView(
            viewModel: viewModel,
            settings: settings,
            onRefresh: refreshAndMaybePresentAlert,
            onOpenAlert: {
                presentAlertWindow()
            }
        )
        .task(id: monitorLoopID) {
            viewModel.apply(settings: settings)
            alertSessionController.apply(settings: settings)
            await runMonitoringLoop()
        }
        .onChange(of: settings) { _, newSettings in
            viewModel.apply(settings: newSettings)
            alertSessionController.apply(settings: newSettings)
        }
    }

    private var monitorLoopID: String {
        let ignoredSignature = settings.ignoredBundleIdentifiers.joined(separator: ",")
        return "\(settings.detectionIntervalSeconds)-\(settings.defaultSelectedAppCount)-\(settings.forceQuitRevealDelaySeconds)-\(settings.relaunchDelaySeconds)-\(settings.snoozeUntil?.timeIntervalSince1970 ?? 0)-\(ignoredSignature)"
    }

    private func refreshAndMaybePresentAlert() {
        Task {
            await refreshAndMaybePresentAlertTask()
        }
    }

    private func runMonitoringLoop() async {
        while !Task.isCancelled {
            await refreshAndMaybePresentAlertTask()

            let intervalSeconds = max(1, settings.detectionIntervalSeconds)
            try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
        }
    }

    private func refreshAndMaybePresentAlertTask() async {
        await viewModel.refresh()

        let reasons = viewModel.latestReasons
        isIgnoringCurrentIncident = presentationPolicy.shouldKeepIgnoringCurrentIncident(
            isIgnoringCurrentIncident: isIgnoringCurrentIncident,
            triggerReasons: reasons
        )

        guard let snapshot = viewModel.latestSnapshot else {
            return
        }

        if isAlertActive {
            alertSessionController.refreshProcesses(snapshot.processes)
        }

        guard presentationPolicy.shouldPresentAlert(
            triggerReasons: reasons,
            isAlertActive: isAlertActive,
            isIgnoringCurrentIncident: isIgnoringCurrentIncident,
            snoozeUntil: settings.snoozeUntil,
            now: Date()
        ) else {
            return
        }

        alertSessionController.present(
            snapshot: snapshot,
            selectedPIDs: selectionPlanner.selectDefaultPIDs(
                from: snapshot.processes,
                count: settings.defaultSelectedAppCount,
                ignoredBundleIdentifiers: settings.ignoredBundleIdentifiers
            )
        )
        presentAlertWindow()
    }

    private var isAlertActive: Bool {
        switch alertSessionController.state.phase {
        case .presenting, .quitRequested, .forceQuitAvailable:
            true
        case .idle, .completed, .dismissed:
            false
        }
    }

    private func presentAlertWindow() {
        openWindow(id: "memory-alert")
    }
}
