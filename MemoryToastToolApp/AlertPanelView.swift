import SwiftUI

struct AlertPanelView: View {
    @ObservedObject var controller: AlertSessionController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "alert.title"))
                .font(.title3.weight(.semibold))

            if controller.state.phase == .quitRequested {
                Text(String(format: String(localized: "alert.countdown %lld"), controller.state.countdownRemaining))
                    .foregroundStyle(.secondary)
            }

            List(controller.state.visibleProcesses) { process in
                HStack {
                    Text(process.appName)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(process.memoryBytes), countStyle: .memory))
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Button(String(localized: "alert.action.quit_selected")) {
                    Task { await controller.requestQuitSelected() }
                }

                Button(String(localized: "alert.action.force_quit_selected")) {}
                    .disabled(controller.state.phase != .forceQuitAvailable)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 320)
    }
}
