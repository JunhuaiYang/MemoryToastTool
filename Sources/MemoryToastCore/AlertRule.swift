import Foundation

public enum AlertRule: Equatable, Sendable {
    case usedMemoryRatioAbove(Double)
    case availableMemoryBelow(bytes: UInt64)
    case swapUsedAbove(bytes: UInt64)
    case pressureAtLeast(level: MemoryPressureLevel)
}
