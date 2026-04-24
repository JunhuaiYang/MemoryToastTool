import Foundation

@MainActor
public final class AlertSessionController {
    private let countdownSeconds: Int
    private let appActionService: AppActionService
    private let relaunchService: AppRelaunchService

    public private(set) var state: AlertSessionState

    public init(
        countdownSeconds: Int,
        appActionService: AppActionService,
        relaunchService: AppRelaunchService
    ) {
        self.countdownSeconds = countdownSeconds
        self.appActionService = appActionService
        self.relaunchService = relaunchService
        self.state = AlertSessionState()
    }

    public func present(snapshot: MemorySnapshot, selectedPIDs: [Int32]) {
        state.phase = .presenting
        state.selectedPIDs = selectedPIDs
        state.forceQuitPIDs = []
        state.visibleProcesses = snapshot.processes
        state.isSelectionLocked = false
        state.countdownRemaining = countdownSeconds
    }

    public func requestQuitSelected() async {
        state.phase = .quitRequested
        state.isSelectionLocked = true
        state.countdownRemaining = countdownSeconds

        let selectedBundleIdentifiers = state.visibleProcesses
            .filter { state.selectedPIDs.contains($0.pid) }
            .compactMap(\.bundleIdentifier)

        for bundleIdentifier in selectedBundleIdentifiers {
            try? await appActionService.requestQuit(bundleIdentifier: bundleIdentifier)
        }
    }

    public func refreshProcesses(_ processes: [ProcessSample]) {
        state.visibleProcesses = processes.filter(\.isRunning)

        let alive = Set(state.visibleProcesses.map(\.pid))
        if state.selectedPIDs.allSatisfy({ !alive.contains($0) }) {
            state.phase = .completed
            state.forceQuitPIDs = []
        }
    }

    public func finishCountdown() async {
        state.countdownRemaining = 0

        let alive = Set(state.visibleProcesses.map(\.pid))
        state.forceQuitPIDs = state.selectedPIDs.filter { alive.contains($0) }
        state.phase = state.forceQuitPIDs.isEmpty ? .completed : .forceQuitAvailable
    }

    public func dismiss() {
        state.phase = .dismissed
    }

    public func relaunch(bundleIdentifier: String) {
        relaunchService.relaunch(bundleIdentifier: bundleIdentifier)
    }
}
