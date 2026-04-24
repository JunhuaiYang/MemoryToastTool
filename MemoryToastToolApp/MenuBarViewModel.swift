import Foundation
import Combine

@MainActor
final class MenuBarViewModel: ObservableObject {
    private let monitor: MemoryMonitor
    private let ruleEvaluator: RuleEvaluator
    private var activeRules: [AlertRule] = []

    @Published var latestSnapshot: MemorySnapshot?
    @Published var latestReasons: [String] = []
    @Published var isRefreshing = false

    init(
        monitor: MemoryMonitor = MemoryMonitor(),
        ruleEvaluator: RuleEvaluator = RuleEvaluator()
    ) {
        self.monitor = monitor
        self.ruleEvaluator = ruleEvaluator
    }

    var statusText: String {
        switch latestSnapshot?.pressureLevel {
        case .critical:
            String(localized: "menu.status.critical")
        case .warning:
            String(localized: "menu.status.warning")
        default:
            String(localized: "menu.status.normal")
        }
    }

    var topProcesses: [ProcessSample] {
        Array((latestSnapshot?.processes ?? []).prefix(5))
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
            latestReasons = ruleEvaluator.evaluate(snapshot: snapshot, rules: rules).reasons
        } catch {
            latestReasons = [error.localizedDescription]
        }
    }
}
