import Foundation
import Combine

@MainActor
public final class AlertSessionController: ObservableObject {
    private let appActionService: AppActionService
    private let relaunchService: AppRelaunchService
    private let sleep: @Sendable (UInt64) async throws -> Void

    private var countdownTask: Task<Void, Never>?
    private var countdownSeconds: Int
    private var relaunchDelaySeconds: Int
    private var hasScheduledRelaunch = false
    private var bundleIdentifiersByPID: [Int32: String] = [:]

    @Published public private(set) var state: AlertSessionState

    public init(
        countdownSeconds: Int,
        relaunchDelaySeconds: Int,
        appActionService: AppActionService,
        relaunchService: AppRelaunchService,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.countdownSeconds = countdownSeconds
        self.relaunchDelaySeconds = relaunchDelaySeconds
        self.appActionService = appActionService
        self.relaunchService = relaunchService
        self.sleep = sleep
        self.state = AlertSessionState()
    }

    deinit {
        countdownTask?.cancel()
    }

    public func apply(settings: AppSettings) {
        countdownSeconds = max(1, settings.forceQuitRevealDelaySeconds)
        relaunchDelaySeconds = max(0, settings.relaunchDelaySeconds)
    }

    public func present(snapshot: MemorySnapshot, selectedPIDs: [Int32]) {
        countdownTask?.cancel()
        hasScheduledRelaunch = false

        let visibleProcesses = snapshot.processes.filter(\.isRunning)
        let orderedSelection = orderedPIDs(selectedPIDs, within: visibleProcesses)
        bundleIdentifiersByPID = dictionaryByPID(from: visibleProcesses)

        state.phase = .presenting
        state.selectedPIDs = orderedSelection
        state.originalSelectedPIDs = orderedSelection
        state.forceQuitPIDs = []
        state.forceQuitRequestedPIDs = []
        state.relaunchAfterQuitPIDs = []
        state.visibleProcesses = visibleProcesses
        state.isSelectionLocked = false
        state.countdownRemaining = countdownSeconds
        state.countdownTotalSeconds = countdownSeconds
    }

    public func setSelected(pid: Int32, isSelected: Bool) {
        guard !state.isSelectionLocked else {
            return
        }

        var selected = Set(state.selectedPIDs)
        if isSelected {
            selected.insert(pid)
        } else {
            selected.remove(pid)
        }

        state.selectedPIDs = orderedPIDs(Array(selected), within: state.visibleProcesses)
        if !isSelected {
            state.relaunchAfterQuitPIDs.removeAll { $0 == pid }
        }
    }

    public func setRelaunchAfterQuit(pid: Int32, isEnabled: Bool) {
        guard !state.isSelectionLocked else {
            return
        }

        var relaunchPIDs = Set(state.relaunchAfterQuitPIDs)
        if isEnabled {
            relaunchPIDs.insert(pid)
        } else {
            relaunchPIDs.remove(pid)
        }

        state.relaunchAfterQuitPIDs = orderedPIDs(Array(relaunchPIDs), within: state.visibleProcesses)
    }

    public func requestQuitSelected() async {
        guard !state.selectedPIDs.isEmpty else {
            return
        }

        state.phase = .quitRequested
        state.isSelectionLocked = true
        state.originalSelectedPIDs = state.selectedPIDs
        state.forceQuitPIDs = []
        state.countdownRemaining = countdownSeconds
        state.countdownTotalSeconds = countdownSeconds

        let selectedBundleIdentifiers = state.visibleProcesses
            .filter { state.selectedPIDs.contains($0.pid) }
            .compactMap(\.bundleIdentifier)

        for bundleIdentifier in selectedBundleIdentifiers {
            try? await appActionService.requestQuit(bundleIdentifier: bundleIdentifier)
        }
    }

    public func startCountdown() {
        guard state.phase == .quitRequested else {
            return
        }

        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else {
                return
            }

            while !Task.isCancelled {
                if self.state.phase != .quitRequested || self.state.countdownRemaining <= 0 {
                    break
                }

                try? await self.sleep(1_000_000_000)
                guard !Task.isCancelled else {
                    return
                }

                if self.state.phase != .quitRequested {
                    break
                }

                self.state.countdownRemaining = max(0, self.state.countdownRemaining - 1)
                if self.state.countdownRemaining == 0 {
                    await self.finishCountdown()
                }
            }
        }
    }

    public func refreshProcesses(_ processes: [ProcessSample]) {
        let visibleProcesses = processes.filter(\.isRunning)
        state.visibleProcesses = visibleProcesses
        bundleIdentifiersByPID.merge(dictionaryByPID(from: visibleProcesses)) { current, _ in current }

        if !state.isSelectionLocked {
            state.selectedPIDs = orderedPIDs(state.selectedPIDs, within: visibleProcesses)
            state.relaunchAfterQuitPIDs = orderedPIDs(state.relaunchAfterQuitPIDs, within: visibleProcesses)
        }

        completeIfNeeded(alivePIDs: Set(visibleProcesses.map(\.pid)))
    }

    public func finishCountdown() async {
        countdownTask?.cancel()
        state.countdownRemaining = 0

        let alive = Set(state.visibleProcesses.map(\.pid))
        state.forceQuitPIDs = state.originalSelectedPIDs.filter { alive.contains($0) }
        state.phase = state.forceQuitPIDs.isEmpty ? .completed : .forceQuitAvailable

        if state.phase == .completed {
            await scheduleRelaunchIfNeeded()
        }
    }

    public func forceQuitSelected() async {
        guard state.phase == .forceQuitAvailable else {
            return
        }

        let visibleByPID = Dictionary(uniqueKeysWithValues: state.visibleProcesses.map { ($0.pid, $0) })
        state.forceQuitRequestedPIDs = state.forceQuitPIDs

        for pid in state.forceQuitPIDs {
            guard let bundleIdentifier = visibleByPID[pid]?.bundleIdentifier else {
                continue
            }
            try? await appActionService.forceQuit(bundleIdentifier: bundleIdentifier)
        }
    }

    public func dismiss() {
        countdownTask?.cancel()
        state.phase = .dismissed
    }

    public func relaunch(bundleIdentifier: String) {
        relaunchService.relaunch(bundleIdentifier: bundleIdentifier)
    }

    private func completeIfNeeded(alivePIDs: Set<Int32>) {
        guard !state.originalSelectedPIDs.isEmpty else {
            return
        }

        if state.originalSelectedPIDs.allSatisfy({ !alivePIDs.contains($0) }) {
            countdownTask?.cancel()
            state.phase = .completed
            state.forceQuitPIDs = []
            Task { [weak self] in
                await self?.scheduleRelaunchIfNeeded()
            }
        }
    }

    private func scheduleRelaunchIfNeeded() async {
        guard !hasScheduledRelaunch else {
            return
        }
        hasScheduledRelaunch = true

        let relaunchCandidates = state.originalSelectedPIDs.filter { pid in
            state.relaunchAfterQuitPIDs.contains(pid) && !state.forceQuitRequestedPIDs.contains(pid)
        }

        let bundleIdentifiers = relaunchCandidates.compactMap { pid in
            bundleIdentifiersByPID[pid]
        }

        if relaunchDelaySeconds > 0 {
            try? await sleep(UInt64(relaunchDelaySeconds) * 1_000_000_000)
        }

        for bundleIdentifier in bundleIdentifiers {
            relaunchService.relaunch(bundleIdentifier: bundleIdentifier)
        }
    }

    private func orderedPIDs(_ pids: [Int32], within processes: [ProcessSample]) -> [Int32] {
        let wanted = Set(pids)
        return processes.map(\.pid).filter { wanted.contains($0) }
    }

    private func dictionaryByPID(from processes: [ProcessSample]) -> [Int32: String] {
        Dictionary(uniqueKeysWithValues: processes.compactMap { process in
            guard let bundleIdentifier = process.bundleIdentifier else {
                return nil
            }
            return (process.pid, bundleIdentifier)
        })
    }
}
