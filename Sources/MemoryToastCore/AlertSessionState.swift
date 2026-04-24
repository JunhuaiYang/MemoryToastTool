import Foundation

public enum AlertPhase: Equatable, Sendable {
    case idle
    case presenting
    case quitRequested
    case forceQuitAvailable
    case completed
    case dismissed
}

public struct AlertSessionState: Equatable, Sendable {
    public var phase: AlertPhase
    public var selectedPIDs: [Int32]
    public var forceQuitPIDs: [Int32]
    public var visibleProcesses: [ProcessSample]
    public var isSelectionLocked: Bool
    public var countdownRemaining: Int

    public init(
        phase: AlertPhase = .idle,
        selectedPIDs: [Int32] = [],
        forceQuitPIDs: [Int32] = [],
        visibleProcesses: [ProcessSample] = [],
        isSelectionLocked: Bool = false,
        countdownRemaining: Int = 0
    ) {
        self.phase = phase
        self.selectedPIDs = selectedPIDs
        self.forceQuitPIDs = forceQuitPIDs
        self.visibleProcesses = visibleProcesses
        self.isSelectionLocked = isSelectionLocked
        self.countdownRemaining = countdownRemaining
    }
}
