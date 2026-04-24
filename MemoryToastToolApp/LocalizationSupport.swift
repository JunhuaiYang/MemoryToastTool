import Foundation
import SwiftUI

extension AppLanguage {
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

func appLocale(for language: AppLanguage?) -> Locale {
    language?.locale ?? .autoupdatingCurrent
}

func localizedString(_ key: String, language: AppLanguage?) -> String {
    localizedBundle(for: language).localizedString(forKey: key, value: nil, table: nil)
}

func localizedFormat(_ key: String, language: AppLanguage?, _ arguments: CVarArg...) -> String {
    String(
        format: localizedString(key, language: language),
        locale: appLocale(for: language),
        arguments: arguments
    )
}

func localizedRuleReason(_ reason: TriggeredRuleReason, language: AppLanguage?) -> String {
    switch reason {
    case .usedMemoryRatioAbove(let threshold):
        return localizedFormat("rule.used_ratio_above %@", language: language, NumberFormatter.localizedString(from: NSNumber(value: threshold), number: .percent))
    case .availableMemoryBelow(let bytes):
        return localizedFormat("rule.available_below %@", language: language, ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory))
    case .swapUsedAbove(let bytes):
        return localizedFormat("rule.swap_above %@", language: language, ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory))
    case .pressureAtLeast(let level):
        return localizedFormat("rule.pressure_at_least %@", language: language, localizedPressureLevel(level, language: language))
    }
}

func localizedPressureLevel(_ level: MemoryPressureLevel, language: AppLanguage?) -> String {
    switch level {
    case .normal:
        return localizedString("menu.status.normal", language: language)
    case .warning:
        return localizedString("menu.status.warning", language: language)
    case .critical:
        return localizedString("menu.status.critical", language: language)
    }
}

private func localizedBundle(for language: AppLanguage?) -> Bundle {
    guard
        let language,
        let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
        let bundle = Bundle(path: path)
    else {
        return .main
    }

    return bundle
}
