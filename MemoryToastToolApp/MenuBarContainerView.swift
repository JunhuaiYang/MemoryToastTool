import SwiftUI

struct MenuBarContainerView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var alertSessionController: AlertSessionController
    @Binding var settings: AppSettings

    var body: some View {
        MenuBarView(
            viewModel: viewModel,
            settings: settings,
            onRefresh: refreshAndMaybePresentAlert,
            onOpenAlert: {
                presentAlertWindow()
            }
        )
        .task {
            viewModel.apply(settings: settings)
            await refreshAndMaybePresentAlertTask()
        }
    }

    private func refreshAndMaybePresentAlert() {
        Task {
            await refreshAndMaybePresentAlertTask()
        }
    }

    private func refreshAndMaybePresentAlertTask() async {
        await viewModel.refresh()

        guard
            let snapshot = viewModel.latestSnapshot,
            !viewModel.latestReasons.isEmpty
        else {
            return
        }

        alertSessionController.present(
            snapshot: snapshot,
            selectedPIDs: Array(snapshot.processes.prefix(settings.defaultSelectedAppCount)).map(\.pid)
        )
        presentAlertWindow()
    }

    private func presentAlertWindow() {
        openWindow(id: "memory-alert")
    }
}
