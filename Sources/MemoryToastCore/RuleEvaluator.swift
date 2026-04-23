import Foundation

public struct RuleEvaluationResult: Equatable, Sendable {
    public let isTriggered: Bool
    public let reasons: [String]

    public init(isTriggered: Bool, reasons: [String]) {
        self.isTriggered = isTriggered
        self.reasons = reasons
    }
}

public struct RuleEvaluator {
    public init() {}

    public func evaluate(snapshot: MemorySnapshot, rules: [AlertRule]) -> RuleEvaluationResult {
        let reasons = rules.compactMap { rule -> String? in
            switch rule {
            case .usedMemoryRatioAbove(let threshold) where snapshot.usedMemoryRatio > threshold:
                return "used ratio > \(threshold)"
            case .availableMemoryBelow(let bytes) where snapshot.availableMemoryBytes < bytes:
                return "available < \(bytes)"
            case .swapUsedAbove(let bytes) where snapshot.swapUsedBytes > bytes:
                return "swap > \(bytes)"
            case .pressureAtLeast(let level) where snapshot.pressureLevel >= level:
                return "pressure >= \(level.rawValue)"
            default:
                return nil
            }
        }

        return RuleEvaluationResult(
            isTriggered: !reasons.isEmpty,
            reasons: reasons
        )
    }
}
