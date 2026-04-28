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

    public func present(
        snapshot: MemorySnapshot,
        matchedReasons: [TriggeredRuleReason] = [],
        selectedPIDs: [Int32]
    ) {
        countdownTask?.cancel()
        hasScheduledRelaunch = false

        let visibleTreeRoots = effectiveTreeRoots(from: snapshot).filter(\.isRunning)
        let visibleProcesses = flatten(visibleTreeRoots)
        let expandedSelection = expandSelectionToDescendants(selectedPIDs, in: visibleTreeRoots)
        let orderedSelection = orderedPIDs(expandedSelection, within: visibleProcesses)
        bundleIdentifiersByPID = dictionaryByPID(from: visibleProcesses)

        state.phase = .presenting
        state.snapshot = snapshot
        state.matchedReasons = matchedReasons
        state.selectedPIDs = orderedSelection
        state.originalSelectedPIDs = orderedSelection
        state.forceQuitPIDs = []
        state.forceQuitRequestedPIDs = []
        state.relaunchAfterQuitPIDs = []
        state.expandedPIDs = []
        state.isSelectionLocked = false
        state.isForceQuitConfirmationPresented = false
        state.countdownRemaining = countdownSeconds
        state.countdownTotalSeconds = countdownSeconds
        updateVisibleState(with: visibleTreeRoots)
    }

    public func setSelected(pid: Int32, isSelected: Bool) {
        guard !state.isSelectionLocked else {
            return
        }

        var selected = Set(state.selectedPIDs)
        let affectedPIDs = descendantPIDs(of: pid, in: state.visibleTreeRoots)

        if isSelected {
            selected.formUnion(affectedPIDs)
        } else {
            selected.subtract(affectedPIDs)
        }

        state.selectedPIDs = orderedPIDs(Array(selected), within: state.visibleProcesses)
        updateVisibleState(with: state.visibleTreeRoots)
        if !isSelected {
            let affectedSet = Set(affectedPIDs)
            state.relaunchAfterQuitPIDs.removeAll { affectedSet.contains($0) }
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
        state.isForceQuitConfirmationPresented = false
        state.countdownRemaining = countdownSeconds
        state.countdownTotalSeconds = countdownSeconds

        let selectedProcesses = state.visibleProcesses.filter { state.selectedPIDs.contains($0.pid) }

        for process in selectedProcesses {
            try? await appActionService.requestQuit(pid: process.pid, bundleIdentifier: process.bundleIdentifier)
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
        let visibleTreeRoots = processes.filter(\.isRunning).map { process in
            ProcessTreeNode(
                pid: process.pid,
                parentPID: process.parentPID,
                processName: process.appName,
                bundleIdentifier: process.bundleIdentifier,
                memoryBytes: process.memoryBytes,
                aggregateMemoryBytes: process.aggregateMemoryBytes,
                isRunning: process.isRunning,
                children: []
            )
        }
        updateVisibleState(with: visibleTreeRoots)
        bundleIdentifiersByPID.merge(dictionaryByPID(from: state.visibleProcesses)) { current, _ in current }

        if !state.isSelectionLocked {
            state.relaunchAfterQuitPIDs = orderedPIDs(state.relaunchAfterQuitPIDs, within: state.visibleProcesses)
        }

        completeIfNeeded(alivePIDs: Set(state.visibleProcesses.map(\.pid)))
    }

    public func refresh(snapshot: MemorySnapshot, matchedReasons: [TriggeredRuleReason]) {
        let visibleTreeRoots = effectiveTreeRoots(from: snapshot).filter(\.isRunning)
        state.snapshot = snapshot
        state.matchedReasons = matchedReasons
        updateVisibleState(with: visibleTreeRoots)
        bundleIdentifiersByPID.merge(dictionaryByPID(from: state.visibleProcesses)) { current, _ in current }

        if !state.isSelectionLocked {
            state.relaunchAfterQuitPIDs = orderedPIDs(state.relaunchAfterQuitPIDs, within: state.visibleProcesses)
        }

        completeIfNeeded(alivePIDs: Set(state.visibleProcesses.map(\.pid)))
    }

    public func finishCountdown() async {
        countdownTask?.cancel()
        state.countdownRemaining = 0

        let alive = Set(state.visibleProcesses.map(\.pid))
        state.forceQuitPIDs = state.originalSelectedPIDs.filter { alive.contains($0) }
        state.phase = state.forceQuitPIDs.isEmpty ? .completed : .waitingForQuitCompletion
        state.isForceQuitConfirmationPresented = !state.forceQuitPIDs.isEmpty

        if state.phase == .completed {
            await scheduleRelaunchIfNeeded()
        }
    }

    public func forceQuitSelected() async {
        guard !state.forceQuitPIDs.isEmpty else {
            return
        }

        let visibleByPID = Dictionary(uniqueKeysWithValues: state.visibleProcesses.map { ($0.pid, $0) })
        state.isForceQuitConfirmationPresented = false
        state.forceQuitRequestedPIDs = state.forceQuitPIDs

        for pid in state.forceQuitPIDs {
            guard let process = visibleByPID[pid] else {
                continue
            }
            try? await appActionService.forceQuit(pid: pid, bundleIdentifier: process.bundleIdentifier)
        }
    }

    public func continueWaitingAfterForceQuitPrompt() {
        state.isForceQuitConfirmationPresented = false
        if state.phase == .quitRequested {
            state.phase = .waitingForQuitCompletion
        }
    }

    public func dismiss() {
        countdownTask?.cancel()
        state.phase = .dismissed
    }

    public func selectionState(for pid: Int32) -> TreeSelectionState {
        let descendantPIDs = descendantPIDs(of: pid, in: state.visibleTreeRoots)
        guard !descendantPIDs.isEmpty else {
            return state.selectedPIDs.contains(pid) ? .selected : .unselected
        }

        let selectedPIDs = Set(state.selectedPIDs)
        let selectedCount = descendantPIDs.filter { selectedPIDs.contains($0) }.count
        if selectedCount == 0 {
            return .unselected
        }
        if selectedCount == descendantPIDs.count {
            return .selected
        }
        return .partiallySelected
    }

    public func isExpanded(pid: Int32) -> Bool {
        state.expandedPIDs.contains(pid)
    }

    public func toggleExpanded(pid: Int32) {
        if state.expandedPIDs.contains(pid) {
            state.expandedPIDs.remove(pid)
        } else {
            state.expandedPIDs.insert(pid)
        }
    }

    public func relaunch(bundleIdentifier: String) {
        relaunchService.relaunch(bundleIdentifier: bundleIdentifier)
    }

    private func completeIfNeeded(alivePIDs: Set<Int32>) {
        guard !state.originalSelectedPIDs.isEmpty else {
            return
        }

        state.forceQuitPIDs = state.originalSelectedPIDs.filter { alivePIDs.contains($0) }
        state.selectedPIDs = orderedPIDs(state.selectedPIDs, within: state.visibleProcesses)

        if state.originalSelectedPIDs.allSatisfy({ !alivePIDs.contains($0) }) {
            countdownTask?.cancel()
            state.phase = .completed
            state.forceQuitPIDs = []
            state.isForceQuitConfirmationPresented = false
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

    private func updateVisibleState(with roots: [ProcessTreeNode]) {
        let orderedRoots = orderedRootsBySelection(roots, selectedPIDs: state.selectedPIDs)
        let visibleProcesses = flatten(orderedRoots)

        state.visibleTreeRoots = orderedRoots
        state.visibleProcesses = visibleProcesses
        state.selectedPIDs = orderedPIDs(state.selectedPIDs, within: visibleProcesses)
    }

    private func dictionaryByPID(from processes: [ProcessSample]) -> [Int32: String] {
        Dictionary(uniqueKeysWithValues: processes.compactMap { process in
            guard let bundleIdentifier = process.bundleIdentifier else {
                return nil
            }
            return (process.pid, bundleIdentifier)
        })
    }

    private func effectiveTreeRoots(from snapshot: MemorySnapshot) -> [ProcessTreeNode] {
        if !snapshot.processTreeRoots.isEmpty {
            return snapshot.processTreeRoots
        }

        return snapshot.processes.map { process in
            ProcessTreeNode(
                pid: process.pid,
                parentPID: process.parentPID,
                processName: process.appName,
                bundleIdentifier: process.bundleIdentifier,
                memoryBytes: process.memoryBytes,
                aggregateMemoryBytes: process.aggregateMemoryBytes,
                isRunning: process.isRunning,
                children: []
            )
        }
    }

    private func flatten(_ roots: [ProcessTreeNode]) -> [ProcessSample] {
        roots.flatMap(flattenNode)
    }

    private func orderedRootsBySelection(_ roots: [ProcessTreeNode], selectedPIDs: [Int32]) -> [ProcessTreeNode] {
        let selectedPIDSet = Set(selectedPIDs)

        return roots.sorted { lhs, rhs in
            let lhsIsSelected = containsSelectedPID(lhs, selectedPIDSet: selectedPIDSet)
            let rhsIsSelected = containsSelectedPID(rhs, selectedPIDSet: selectedPIDSet)

            if lhsIsSelected != rhsIsSelected {
                return lhsIsSelected && !rhsIsSelected
            }

            if lhs.aggregateMemoryBytes != rhs.aggregateMemoryBytes {
                return lhs.aggregateMemoryBytes > rhs.aggregateMemoryBytes
            }

            return lhs.pid < rhs.pid
        }
    }

    private func containsSelectedPID(_ node: ProcessTreeNode, selectedPIDSet: Set<Int32>) -> Bool {
        if selectedPIDSet.contains(node.pid) {
            return true
        }

        return node.children.contains { child in
            containsSelectedPID(child, selectedPIDSet: selectedPIDSet)
        }
    }

    private func flattenNode(_ node: ProcessTreeNode) -> [ProcessSample] {
        let process = ProcessSample(
            pid: node.pid,
            parentPID: node.parentPID,
            appName: node.processName,
            bundleIdentifier: node.bundleIdentifier,
            memoryBytes: node.memoryBytes,
            aggregateMemoryBytes: node.aggregateMemoryBytes,
            isRunning: node.isRunning,
            childPIDs: node.children.map(\.pid)
        )

        return [process] + node.children.flatMap(flattenNode)
    }

    private func expandSelectionToDescendants(_ pids: [Int32], in roots: [ProcessTreeNode]) -> [Int32] {
        let expanded = Set(pids.flatMap { descendantPIDs(of: $0, in: roots) })
        return Array(expanded)
    }

    private func descendantPIDs(of pid: Int32, in roots: [ProcessTreeNode]) -> [Int32] {
        for root in roots {
            if let descendantPIDs = descendantPIDs(of: pid, in: root) {
                return descendantPIDs
            }
        }

        return [pid]
    }

    private func descendantPIDs(of pid: Int32, in node: ProcessTreeNode) -> [Int32]? {
        if node.pid == pid {
            return [node.pid] + node.children.flatMap { child in
                descendantPIDs(in: child)
            }
        }

        for child in node.children {
            if let descendantPIDs = descendantPIDs(of: pid, in: child) {
                return descendantPIDs
            }
        }

        return nil
    }

    private func descendantPIDs(in node: ProcessTreeNode) -> [Int32] {
        [node.pid] + node.children.flatMap(descendantPIDs)
    }
}
