import Foundation
import Combine

@MainActor
final class MenuBarViewModel: ObservableObject {
    private let monitor: MemoryMonitor
    private let ruleEvaluator: RuleEvaluator
    private var activeRules: [AlertRule] = []

    @Published var latestSnapshot: MemorySnapshot?
    @Published var latestTreeRoots: [ProcessTreeNode] = []
    @Published var latestReasons: [TriggeredRuleReason] = []
    @Published var isRefreshing = false

    init(
        monitor: MemoryMonitor = MemoryMonitor(),
        ruleEvaluator: RuleEvaluator = RuleEvaluator()
    ) {
        self.monitor = monitor
        self.ruleEvaluator = ruleEvaluator
    }

    var statusLevel: MemoryPressureLevel {
        latestSnapshot?.pressureLevel ?? .normal
    }

    var latestDisplayProcesses: [ProcessSample] {
        latestSnapshot?.processes ?? []
    }

    func apply(settings: AppSettings) {
        activeRules = [
            .availableMemoryBelow(bytes: settings.availableMemoryAlertThresholdBytes),
            .swapUsedAbove(bytes: settings.swapUsedAlertThresholdBytes)
        ]
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let monitor = self.monitor
        let ruleEvaluator = self.ruleEvaluator
        let rules = self.activeRules

        do {
            let snapshot = try await monitor.sample()
            latestSnapshot = snapshot
            latestTreeRoots = snapshot.processTreeRoots
            latestReasons = ruleEvaluator.evaluate(snapshot: snapshot, rules: rules).matches
        } catch {
            latestTreeRoots = []
            latestReasons = []
        }
    }

    func refreshAndBuildAlertPayload() async -> (MemorySnapshot, [ProcessTreeNode], [TriggeredRuleReason])? {
        await refresh()

        guard let snapshot = latestSnapshot else {
            return nil
        }

        return (snapshot, latestTreeRoots, latestReasons)
    }
}
