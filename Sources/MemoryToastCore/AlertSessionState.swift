import Foundation

public enum AlertPhase: Equatable, Sendable {
    case idle
    case presenting
    case quitRequested
    case forceQuitAvailable
    case completed
    case dismissed
}

public enum TreeSelectionState: Equatable, Sendable {
    case unselected
    case selected
    case partiallySelected
}

public struct AlertSessionState: Equatable, Sendable {
    public var phase: AlertPhase
    public var selectedPIDs: [Int32]
    public var originalSelectedPIDs: [Int32]
    public var forceQuitPIDs: [Int32]
    public var forceQuitRequestedPIDs: [Int32]
    public var relaunchAfterQuitPIDs: [Int32]
    public var visibleProcesses: [ProcessSample]
    public var visibleTreeRoots: [ProcessTreeNode]
    public var expandedPIDs: Set<Int32>
    public var matchedReasons: [TriggeredRuleReason]
    public var snapshot: MemorySnapshot?
    public var isSelectionLocked: Bool
    public var countdownRemaining: Int
    public var countdownTotalSeconds: Int

    public init(
        phase: AlertPhase = .idle,
        selectedPIDs: [Int32] = [],
        originalSelectedPIDs: [Int32] = [],
        forceQuitPIDs: [Int32] = [],
        forceQuitRequestedPIDs: [Int32] = [],
        relaunchAfterQuitPIDs: [Int32] = [],
        visibleProcesses: [ProcessSample] = [],
        visibleTreeRoots: [ProcessTreeNode] = [],
        expandedPIDs: Set<Int32> = [],
        matchedReasons: [TriggeredRuleReason] = [],
        snapshot: MemorySnapshot? = nil,
        isSelectionLocked: Bool = false,
        countdownRemaining: Int = 0,
        countdownTotalSeconds: Int = 0
    ) {
        self.phase = phase
        self.selectedPIDs = selectedPIDs
        self.originalSelectedPIDs = originalSelectedPIDs
        self.forceQuitPIDs = forceQuitPIDs
        self.forceQuitRequestedPIDs = forceQuitRequestedPIDs
        self.relaunchAfterQuitPIDs = relaunchAfterQuitPIDs
        self.visibleProcesses = visibleProcesses
        self.visibleTreeRoots = visibleTreeRoots
        self.expandedPIDs = expandedPIDs
        self.matchedReasons = matchedReasons
        self.snapshot = snapshot
        self.isSelectionLocked = isSelectionLocked
        self.countdownRemaining = countdownRemaining
        self.countdownTotalSeconds = countdownTotalSeconds
    }
}
