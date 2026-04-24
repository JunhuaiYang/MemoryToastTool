import Foundation

public enum TriggeredRuleReason: Equatable, Sendable {
    case usedMemoryRatioAbove(threshold: Double)
    case availableMemoryBelow(bytes: UInt64)
    case swapUsedAbove(bytes: UInt64)
    case pressureAtLeast(level: MemoryPressureLevel)

    public var debugDescription: String {
        switch self {
        case .usedMemoryRatioAbove(let threshold):
            return "used ratio > \(threshold)"
        case .availableMemoryBelow(let bytes):
            return "available < \(bytes)"
        case .swapUsedAbove(let bytes):
            return "swap > \(bytes)"
        case .pressureAtLeast(let level):
            return "pressure >= \(level.rawValue)"
        }
    }
}

public struct RuleEvaluationResult: Equatable, Sendable {
    public let matches: [TriggeredRuleReason]

    public var isTriggered: Bool {
        !matches.isEmpty
    }

    public var reasons: [String] {
        matches.map(\.debugDescription)
    }

    public init(matches: [TriggeredRuleReason]) {
        self.matches = matches
    }
}

public struct RuleEvaluator: Sendable {
    public init() {}

    public func evaluate(snapshot: MemorySnapshot, rules: [AlertRule]) -> RuleEvaluationResult {
        let matches = rules.compactMap { rule -> TriggeredRuleReason? in
            switch rule {
            case .usedMemoryRatioAbove(let threshold) where snapshot.usedMemoryRatio > threshold:
                return .usedMemoryRatioAbove(threshold: threshold)
            case .availableMemoryBelow(let bytes) where snapshot.availableMemoryBytes < bytes:
                return .availableMemoryBelow(bytes: bytes)
            case .swapUsedAbove(let bytes) where snapshot.swapUsedBytes > bytes:
                return .swapUsedAbove(bytes: bytes)
            case .pressureAtLeast(let level) where snapshot.pressureLevel >= level:
                return .pressureAtLeast(level: level)
            default:
                return nil
            }
        }

        return RuleEvaluationResult(matches: matches)
    }
}
