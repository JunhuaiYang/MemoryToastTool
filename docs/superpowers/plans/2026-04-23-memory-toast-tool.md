# Memory Toast Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar application that monitors memory usage, evaluates configurable alert rules, shows a live-updating alert panel, and helps the user quit or force quit high-memory apps safely with bilingual Chinese/English UI.

**Architecture:** Use a Swift Package macOS executable target with `SwiftUI` as the app shell and focused modules for monitoring, rules, process control, alert-session state, persistence, and UI. Keep all system-dependent APIs behind small protocols so the business logic is unit-testable with `swift test`, and use `swift build` as the compile gate for every milestone.

**Tech Stack:** Swift 6.2, SwiftUI, AppKit, Foundation, XCTest, Swift Package Manager

---

## File Structure

### Package and App Entry

- Create: `Package.swift`
- Create: `Sources/MemoryToastTool/MemoryToastToolApp.swift`

### Domain and Persistence

- Create: `Sources/MemoryToastTool/Domain/AppSettings.swift`
- Create: `Sources/MemoryToastTool/Domain/AlertRule.swift`
- Create: `Sources/MemoryToastTool/Domain/MemorySnapshot.swift`
- Create: `Sources/MemoryToastTool/Domain/ProcessSample.swift`
- Create: `Sources/MemoryToastTool/Persistence/SettingsStore.swift`

### Monitoring

- Create: `Sources/MemoryToastTool/Monitoring/MemoryMonitor.swift`
- Create: `Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift`
- Create: `Sources/MemoryToastTool/Monitoring/ProcessSampling.swift`

### Rules

- Create: `Sources/MemoryToastTool/Rules/RuleEvaluator.swift`

### Process Control

- Create: `Sources/MemoryToastTool/ProcessControl/AppActionService.swift`
- Create: `Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift`

### Alert Session

- Create: `Sources/MemoryToastTool/AlertSession/AlertSessionState.swift`
- Create: `Sources/MemoryToastTool/AlertSession/AlertSessionController.swift`

### UI

- Create: `Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift`
- Create: `Sources/MemoryToastTool/UI/MenuBar/MenuBarView.swift`
- Create: `Sources/MemoryToastTool/UI/Alert/AlertPanelViewModel.swift`
- Create: `Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift`
- Create: `Sources/MemoryToastTool/UI/Settings/SettingsView.swift`

### Localization Resources

- Create: `Sources/MemoryToastTool/Resources/en.lproj/Localizable.strings`
- Create: `Sources/MemoryToastTool/Resources/zh-Hans.lproj/Localizable.strings`

### Tests

- Create: `Tests/MemoryToastToolTests/SettingsStoreTests.swift`
- Create: `Tests/MemoryToastToolTests/RuleEvaluatorTests.swift`
- Create: `Tests/MemoryToastToolTests/MemoryMonitorTests.swift`
- Create: `Tests/MemoryToastToolTests/AppActionServiceTests.swift`
- Create: `Tests/MemoryToastToolTests/AlertSessionControllerTests.swift`

## Task 1: Bootstrap the Swift package, app shell, and persisted settings

**Files:**
- Create: `Package.swift`
- Create: `Sources/MemoryToastTool/MemoryToastToolApp.swift`
- Create: `Sources/MemoryToastTool/Domain/AppSettings.swift`
- Create: `Sources/MemoryToastTool/Persistence/SettingsStore.swift`
- Create: `Tests/MemoryToastToolTests/SettingsStoreTests.swift`

- [ ] **Step 1: Create the package manifest and the minimal app target**

```swift
// Package.swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MemoryToastTool",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MemoryToastTool", targets: ["MemoryToastTool"])
    ],
    targets: [
        .executableTarget(
            name: "MemoryToastTool",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "MemoryToastToolTests",
            dependencies: ["MemoryToastTool"]
        )
    ]
)
```

```swift
// Sources/MemoryToastTool/MemoryToastToolApp.swift
import SwiftUI

@main
struct MemoryToastToolApp: App {
    @State private var settingsStore = SettingsStore()

    var body: some Scene {
        MenuBarExtra("Memory Toast Tool", systemImage: "memorychip") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Memory Toast Tool")
                    .font(.headline)
                Text("Bootstrapping...")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        Settings {
            Text("Settings view is not wired yet.")
                .padding(20)
        }
    }
}
```

- [ ] **Step 2: Write the failing settings tests**

```swift
// Tests/MemoryToastToolTests/SettingsStoreTests.swift
import XCTest
@testable import MemoryToastTool

final class SettingsStoreTests: XCTestCase {
    func testDefaultSettingsMatchProductSpec() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function)!)

        let settings = store.load()

        XCTAssertEqual(settings.detectionIntervalSeconds, 30)
        XCTAssertEqual(settings.defaultSelectedAppCount, 3)
        XCTAssertEqual(settings.relaunchDelaySeconds, 5)
        XCTAssertEqual(settings.forceQuitRevealDelaySeconds, 10)
        XCTAssertNil(settings.languageOverride)
    }

    func testSaveRoundTripPersistsValues() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = SettingsStore(defaults: defaults)

        var settings = AppSettings.defaultValue
        settings.detectionIntervalSeconds = 12
        settings.defaultSelectedAppCount = 4
        settings.relaunchDelaySeconds = 9
        settings.languageOverride = .english

        store.save(settings)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.detectionIntervalSeconds, 12)
        XCTAssertEqual(reloaded.defaultSelectedAppCount, 4)
        XCTAssertEqual(reloaded.relaunchDelaySeconds, 9)
        XCTAssertEqual(reloaded.languageOverride, .english)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter SettingsStoreTests`

Expected: FAIL with errors that `SettingsStore`, `AppSettings`, and `languageOverride` do not exist yet.

- [ ] **Step 4: Implement `AppSettings` and `SettingsStore` minimally**

```swift
// Sources/MemoryToastTool/Domain/AppSettings.swift
import Foundation

enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
}

struct AppSettings: Codable, Equatable, Sendable {
    var detectionIntervalSeconds: Int
    var defaultSelectedAppCount: Int
    var relaunchDelaySeconds: Int
    var forceQuitRevealDelaySeconds: Int
    var languageOverride: AppLanguage?

    static let defaultValue = AppSettings(
        detectionIntervalSeconds: 30,
        defaultSelectedAppCount: 3,
        relaunchDelaySeconds: 5,
        forceQuitRevealDelaySeconds: 10,
        languageOverride: nil
    )
}
```

```swift
// Sources/MemoryToastTool/Persistence/SettingsStore.swift
import Foundation

@Observable
final class SettingsStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let settingsKey = "app_settings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: settingsKey),
            let settings = try? decoder.decode(AppSettings.self, from: data)
        else {
            return .defaultValue
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }
}
```

- [ ] **Step 5: Run build and tests to verify the package bootstraps**

Run: `swift build && swift test --filter SettingsStoreTests`

Expected:
- `swift build` succeeds
- both `SettingsStoreTests` tests PASS

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/MemoryToastTool/MemoryToastToolApp.swift Sources/MemoryToastTool/Domain/AppSettings.swift Sources/MemoryToastTool/Persistence/SettingsStore.swift Tests/MemoryToastToolTests/SettingsStoreTests.swift
git commit -m "feat: bootstrap package and persisted settings"
```

## Task 2: Add domain models and rule evaluation

**Files:**
- Create: `Sources/MemoryToastTool/Domain/AlertRule.swift`
- Create: `Sources/MemoryToastTool/Domain/MemorySnapshot.swift`
- Create: `Sources/MemoryToastTool/Domain/ProcessSample.swift`
- Create: `Sources/MemoryToastTool/Rules/RuleEvaluator.swift`
- Create: `Tests/MemoryToastToolTests/RuleEvaluatorTests.swift`

- [ ] **Step 1: Write the failing rule evaluator tests**

```swift
// Tests/MemoryToastToolTests/RuleEvaluatorTests.swift
import XCTest
@testable import MemoryToastTool

final class RuleEvaluatorTests: XCTestCase {
    func testEvaluatorMatchesAvailableMemoryAndSwapRules() {
        let snapshot = MemorySnapshot(
            totalMemoryBytes: 36_000_000_000,
            usedMemoryBytes: 32_000_000_000,
            availableMemoryBytes: 1_500_000_000,
            swapUsedBytes: 5_000_000_000,
            pressureLevel: .warning,
            processes: []
        )

        let rules = [
            AlertRule.availableMemoryBelow(bytes: 2_000_000_000),
            AlertRule.swapUsedAbove(bytes: 4_000_000_000)
        ]

        let result = RuleEvaluator().evaluate(snapshot: snapshot, rules: rules)

        XCTAssertTrue(result.isTriggered)
        XCTAssertEqual(result.reasons.count, 2)
    }

    func testEvaluatorMatchesPressureRule() {
        let snapshot = MemorySnapshot(
            totalMemoryBytes: 36_000_000_000,
            usedMemoryBytes: 20_000_000_000,
            availableMemoryBytes: 12_000_000_000,
            swapUsedBytes: 0,
            pressureLevel: .critical,
            processes: []
        )

        let result = RuleEvaluator().evaluate(
            snapshot: snapshot,
            rules: [.pressureAtLeast(level: .critical)]
        )

        XCTAssertTrue(result.isTriggered)
        XCTAssertEqual(result.reasons, ["pressure >= critical"])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter RuleEvaluatorTests`

Expected: FAIL because `MemorySnapshot`, `AlertRule`, `RuleEvaluator`, and `pressureLevel` are undefined.

- [ ] **Step 3: Implement the domain models and evaluator**

```swift
// Sources/MemoryToastTool/Domain/ProcessSample.swift
import Foundation

struct ProcessSample: Equatable, Identifiable, Sendable {
    let pid: Int32
    let appName: String
    let bundleIdentifier: String?
    let memoryBytes: UInt64
    let isRunning: Bool

    var id: Int32 { pid }
}
```

```swift
// Sources/MemoryToastTool/Domain/MemorySnapshot.swift
import Foundation

enum MemoryPressureLevel: String, Codable, Equatable, Comparable, Sendable {
    case normal
    case warning
    case critical

    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .normal: 0
        case .warning: 1
        case .critical: 2
        }
    }
}

struct MemorySnapshot: Equatable, Sendable {
    let totalMemoryBytes: UInt64
    let usedMemoryBytes: UInt64
    let availableMemoryBytes: UInt64
    let swapUsedBytes: UInt64
    let pressureLevel: MemoryPressureLevel
    let processes: [ProcessSample]

    var usedMemoryRatio: Double {
        guard totalMemoryBytes > 0 else { return 0 }
        return Double(usedMemoryBytes) / Double(totalMemoryBytes)
    }
}
```

```swift
// Sources/MemoryToastTool/Domain/AlertRule.swift
import Foundation

enum AlertRule: Codable, Equatable, Sendable {
    case usedMemoryRatioAbove(Double)
    case availableMemoryBelow(bytes: UInt64)
    case swapUsedAbove(bytes: UInt64)
    case pressureAtLeast(level: MemoryPressureLevel)
}
```

```swift
// Sources/MemoryToastTool/Rules/RuleEvaluator.swift
import Foundation

struct RuleEvaluationResult: Equatable, Sendable {
    let isTriggered: Bool
    let reasons: [String]
}

struct RuleEvaluator {
    func evaluate(snapshot: MemorySnapshot, rules: [AlertRule]) -> RuleEvaluationResult {
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

        return RuleEvaluationResult(isTriggered: !reasons.isEmpty, reasons: reasons)
    }
}
```

- [ ] **Step 4: Run tests and full package build**

Run: `swift build && swift test --filter RuleEvaluatorTests`

Expected:
- `swift build` succeeds
- both `RuleEvaluatorTests` tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MemoryToastTool/Domain/AlertRule.swift Sources/MemoryToastTool/Domain/MemorySnapshot.swift Sources/MemoryToastTool/Domain/ProcessSample.swift Sources/MemoryToastTool/Rules/RuleEvaluator.swift Tests/MemoryToastToolTests/RuleEvaluatorTests.swift
git commit -m "feat: add alert rules and evaluation"
```

## Task 3: Build the monitoring pipeline with test doubles

**Files:**
- Create: `Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift`
- Create: `Sources/MemoryToastTool/Monitoring/ProcessSampling.swift`
- Create: `Sources/MemoryToastTool/Monitoring/MemoryMonitor.swift`
- Create: `Tests/MemoryToastToolTests/MemoryMonitorTests.swift`

- [ ] **Step 1: Write the failing monitoring tests**

```swift
// Tests/MemoryToastToolTests/MemoryMonitorTests.swift
import XCTest
@testable import MemoryToastTool

final class MemoryMonitorTests: XCTestCase {
    func testMonitorReturnsProcessesSortedByMemoryDescending() async throws {
        let systemSampler = StubSystemMemorySampler(
            snapshot: SystemMemorySample(
                totalMemoryBytes: 36_000,
                usedMemoryBytes: 30_000,
                availableMemoryBytes: 2_000,
                swapUsedBytes: 5_000,
                pressureLevel: .warning
            )
        )
        let processSampler = StubProcessSampler(processes: [
            ProcessSample(pid: 1, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 200, isRunning: true),
            ProcessSample(pid: 2, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 900, isRunning: true),
            ProcessSample(pid: 3, appName: "Xcode", bundleIdentifier: "xcode", memoryBytes: 600, isRunning: true)
        ])

        let snapshot = try await MemoryMonitor(systemSampler: systemSampler, processSampler: processSampler).sample()

        XCTAssertEqual(snapshot.processes.map(\.appName), ["Chrome", "Xcode", "Slack"])
        XCTAssertEqual(snapshot.pressureLevel, .warning)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter MemoryMonitorTests`

Expected: FAIL because the samplers, `SystemMemorySample`, and `MemoryMonitor` do not exist yet.

- [ ] **Step 3: Implement monitoring abstractions and the monitor**

```swift
// Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift
import Foundation

struct SystemMemorySample: Equatable, Sendable {
    let totalMemoryBytes: UInt64
    let usedMemoryBytes: UInt64
    let availableMemoryBytes: UInt64
    let swapUsedBytes: UInt64
    let pressureLevel: MemoryPressureLevel
}

protocol SystemMemorySampling: Sendable {
    func sampleSystemMemory() async throws -> SystemMemorySample
}

struct LiveSystemMemorySampler: SystemMemorySampling {
    func sampleSystemMemory() async throws -> SystemMemorySample {
        SystemMemorySample(
            totalMemoryBytes: ProcessInfo.processInfo.physicalMemory,
            usedMemoryBytes: 0,
            availableMemoryBytes: 0,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )
    }
}
```

```swift
// Sources/MemoryToastTool/Monitoring/ProcessSampling.swift
import Foundation

protocol ProcessSampling: Sendable {
    func sampleProcesses() async throws -> [ProcessSample]
}

struct LiveProcessSampler: ProcessSampling {
    func sampleProcesses() async throws -> [ProcessSample] {
        []
    }
}
```

```swift
// Sources/MemoryToastTool/Monitoring/MemoryMonitor.swift
import Foundation

struct MemoryMonitor {
    let systemSampler: SystemMemorySampling
    let processSampler: ProcessSampling

    init(
        systemSampler: SystemMemorySampling = LiveSystemMemorySampler(),
        processSampler: ProcessSampling = LiveProcessSampler()
    ) {
        self.systemSampler = systemSampler
        self.processSampler = processSampler
    }

    func sample() async throws -> MemorySnapshot {
        async let system = systemSampler.sampleSystemMemory()
        async let processes = processSampler.sampleProcesses()

        let systemSample = try await system
        let sortedProcesses = try await processes.sorted { $0.memoryBytes > $1.memoryBytes }

        return MemorySnapshot(
            totalMemoryBytes: systemSample.totalMemoryBytes,
            usedMemoryBytes: systemSample.usedMemoryBytes,
            availableMemoryBytes: systemSample.availableMemoryBytes,
            swapUsedBytes: systemSample.swapUsedBytes,
            pressureLevel: systemSample.pressureLevel,
            processes: sortedProcesses
        )
    }
}
```

```swift
// Add at the bottom of Tests/MemoryToastToolTests/MemoryMonitorTests.swift
private struct StubSystemMemorySampler: SystemMemorySampling {
    let snapshot: SystemMemorySample
    func sampleSystemMemory() async throws -> SystemMemorySample { snapshot }
}

private struct StubProcessSampler: ProcessSampling {
    let processes: [ProcessSample]
    func sampleProcesses() async throws -> [ProcessSample] { processes }
}
```

- [ ] **Step 4: Expand the live samplers after the unit test passes**

Replace the placeholder implementations with the first production-safe version:

```swift
// Sources/MemoryToastTool/Monitoring/LiveProcessSampler additions
import AppKit

struct LiveProcessSampler: ProcessSampling {
    func sampleProcesses() async throws -> [ProcessSample] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            ProcessSample(
                pid: app.processIdentifier,
                appName: app.localizedName ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier,
                memoryBytes: 0,
                isRunning: !app.isTerminated
            )
        }
    }
}
```

Task 6 replaces `memoryBytes: 0` with `proc_pid_rusage`-backed resident memory sampling while keeping the same `ProcessSampling` interface.

- [ ] **Step 5: Run build and tests**

Run: `swift build && swift test --filter MemoryMonitorTests`

Expected:
- `swift build` succeeds
- `MemoryMonitorTests` PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift Sources/MemoryToastTool/Monitoring/ProcessSampling.swift Sources/MemoryToastTool/Monitoring/MemoryMonitor.swift Tests/MemoryToastToolTests/MemoryMonitorTests.swift
git commit -m "feat: add monitoring pipeline abstractions"
```

## Task 4: Implement process control and the alert-session state machine

**Files:**
- Create: `Sources/MemoryToastTool/ProcessControl/AppActionService.swift`
- Create: `Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift`
- Create: `Sources/MemoryToastTool/AlertSession/AlertSessionState.swift`
- Create: `Sources/MemoryToastTool/AlertSession/AlertSessionController.swift`
- Create: `Tests/MemoryToastToolTests/AppActionServiceTests.swift`
- Create: `Tests/MemoryToastToolTests/AlertSessionControllerTests.swift`

- [ ] **Step 1: Write the failing tests for app actions and alert flow**

```swift
// Tests/MemoryToastToolTests/AppActionServiceTests.swift
import XCTest
@testable import MemoryToastTool

final class AppActionServiceTests: XCTestCase {
    func testQuitDelegatesToWorkspaceController() async throws {
        let workspace = StubWorkspaceController()
        let service = AppActionService(workspace: workspace)

        try await service.requestQuit(bundleIdentifier: "com.apple.TextEdit")

        XCTAssertEqual(workspace.quitRequests, ["com.apple.TextEdit"])
    }
}
```

```swift
// Tests/MemoryToastToolTests/AlertSessionControllerTests.swift
import XCTest
@testable import MemoryToastTool

final class AlertSessionControllerTests: XCTestCase {
    func testQuitRequestDisablesSelectionAndRevealsForceQuitAfterCountdown() async throws {
        let controller = AlertSessionController(
            countdownSeconds: 10,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService()
        )

        controller.present(
            snapshot: MemorySnapshot(
                totalMemoryBytes: 10,
                usedMemoryBytes: 9,
                availableMemoryBytes: 1,
                swapUsedBytes: 3,
                pressureLevel: .critical,
                processes: [
                    ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 5, isRunning: true)
                ]
            ),
            selectedPIDs: [7]
        )

        await controller.requestQuitSelected()
        controller.refreshProcesses([
            ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 5, isRunning: true)
        ])
        await controller.finishCountdown()

        XCTAssertEqual(controller.state.phase, .forceQuitAvailable)
        XCTAssertTrue(controller.state.isSelectionLocked)
        XCTAssertEqual(controller.state.forceQuitPIDs, [7])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter AppActionServiceTests && swift test --filter AlertSessionControllerTests`

Expected: FAIL because `AppActionService`, `AlertSessionController`, and related state types do not exist yet.

- [ ] **Step 3: Implement the app-action services**

```swift
// Sources/MemoryToastTool/ProcessControl/AppActionService.swift
import AppKit
import Foundation

protocol WorkspaceControlling: Sendable {
    func requestQuit(bundleIdentifier: String) async throws
    func forceQuit(bundleIdentifier: String) async throws
}

struct LiveWorkspaceController: WorkspaceControlling {
    func requestQuit(bundleIdentifier: String) async throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return }
        _ = app.terminate()
    }

    func forceQuit(bundleIdentifier: String) async throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else { return }
        _ = app.forceTerminate()
    }
}

struct AppActionService {
    let workspace: WorkspaceControlling

    init(workspace: WorkspaceControlling = LiveWorkspaceController()) {
        self.workspace = workspace
    }

    func requestQuit(bundleIdentifier: String) async throws {
        try await workspace.requestQuit(bundleIdentifier: bundleIdentifier)
    }

    func forceQuit(bundleIdentifier: String) async throws {
        try await workspace.forceQuit(bundleIdentifier: bundleIdentifier)
    }
}
```

```swift
// Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift
import AppKit
import Foundation

struct AppRelaunchService {
    func relaunch(bundleIdentifier: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: .init())
    }
}
```

- [ ] **Step 4: Implement the alert-session state machine minimally**

```swift
// Sources/MemoryToastTool/AlertSession/AlertSessionState.swift
import Foundation

enum AlertPhase: Equatable {
    case idle
    case presenting
    case quitRequested
    case forceQuitAvailable
    case completed
    case dismissed
}

struct AlertSessionState: Equatable {
    var phase: AlertPhase = .idle
    var selectedPIDs: [Int32] = []
    var forceQuitPIDs: [Int32] = []
    var visibleProcesses: [ProcessSample] = []
    var isSelectionLocked = false
}
```

```swift
// Sources/MemoryToastTool/AlertSession/AlertSessionController.swift
import Foundation

@MainActor
@Observable
final class AlertSessionController {
    private let countdownSeconds: Int
    private let appActionService: AppActionService
    private let relaunchService: AppRelaunchService

    private(set) var state = AlertSessionState()

    init(
        countdownSeconds: Int,
        appActionService: AppActionService,
        relaunchService: AppRelaunchService
    ) {
        self.countdownSeconds = countdownSeconds
        self.appActionService = appActionService
        self.relaunchService = relaunchService
    }

    func present(snapshot: MemorySnapshot, selectedPIDs: [Int32]) {
        state.phase = .presenting
        state.selectedPIDs = selectedPIDs
        state.visibleProcesses = snapshot.processes
    }

    func requestQuitSelected() async {
        state.phase = .quitRequested
        state.isSelectionLocked = true
    }

    func refreshProcesses(_ processes: [ProcessSample]) {
        state.visibleProcesses = processes.filter(\.isRunning)
    }

    func finishCountdown() async {
        let alive = Set(state.visibleProcesses.map(\.pid))
        state.forceQuitPIDs = state.selectedPIDs.filter { alive.contains($0) }
        state.phase = state.forceQuitPIDs.isEmpty ? .completed : .forceQuitAvailable
    }
}
```

```swift
// Add test doubles at the bottom of the test files
private final class StubWorkspaceController: @unchecked Sendable, WorkspaceControlling {
    var quitRequests: [String] = []
    var forceQuitRequests: [String] = []

    func requestQuit(bundleIdentifier: String) async throws {
        quitRequests.append(bundleIdentifier)
    }

    func forceQuit(bundleIdentifier: String) async throws {
        forceQuitRequests.append(bundleIdentifier)
    }
}
```

- [ ] **Step 5: Run build and the two targeted test files**

Run: `swift build && swift test --filter AppActionServiceTests && swift test --filter AlertSessionControllerTests`

Expected:
- `swift build` succeeds
- both test files PASS

- [ ] **Step 6: Commit**

```bash
git add Sources/MemoryToastTool/ProcessControl/AppActionService.swift Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift Sources/MemoryToastTool/AlertSession/AlertSessionState.swift Sources/MemoryToastTool/AlertSession/AlertSessionController.swift Tests/MemoryToastToolTests/AppActionServiceTests.swift Tests/MemoryToastToolTests/AlertSessionControllerTests.swift
git commit -m "feat: add process actions and alert session state"
```

## Task 5: Build the menu bar UI, alert UI, localization, and wire the app together

**Files:**
- Create: `Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift`
- Create: `Sources/MemoryToastTool/UI/MenuBar/MenuBarView.swift`
- Create: `Sources/MemoryToastTool/UI/Alert/AlertPanelViewModel.swift`
- Create: `Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift`
- Create: `Sources/MemoryToastTool/UI/Settings/SettingsView.swift`
- Create: `Sources/MemoryToastTool/Resources/en.lproj/Localizable.strings`
- Create: `Sources/MemoryToastTool/Resources/zh-Hans.lproj/Localizable.strings`
- Modify: `Sources/MemoryToastTool/MemoryToastToolApp.swift`

- [ ] **Step 1: Write a failing UI-state test for the menu bar view model**

```swift
// Add to Tests/MemoryToastToolTests/AlertSessionControllerTests.swift
func testCompletedSessionClosesWhenNoSelectedProcessesRemain() async throws {
    let controller = AlertSessionController(
        countdownSeconds: 10,
        appActionService: AppActionService(workspace: StubWorkspaceController()),
        relaunchService: AppRelaunchService()
    )

    controller.present(
        snapshot: MemorySnapshot(
            totalMemoryBytes: 10,
            usedMemoryBytes: 9,
            availableMemoryBytes: 1,
            swapUsedBytes: 3,
            pressureLevel: .critical,
            processes: [ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 5, isRunning: true)]
        ),
        selectedPIDs: [7]
    )

    await controller.requestQuitSelected()
    controller.refreshProcesses([])
    await controller.finishCountdown()

    XCTAssertEqual(controller.state.phase, .completed)
}
```

- [ ] **Step 2: Add the localized resource files**

```text
// Sources/MemoryToastTool/Resources/en.lproj/Localizable.strings
"menu.title" = "Memory Toast Tool";
"menu.status.normal" = "Normal";
"menu.status.warning" = "Warning";
"menu.status.critical" = "Critical";
"menu.action.run_check" = "Run Check Now";
"menu.action.settings" = "Settings";
"alert.title" = "Memory pressure is high";
"alert.action.quit_selected" = "Quit Selected";
"alert.action.force_quit_selected" = "Force Quit Selected";
"alert.action.ignore_once" = "Ignore Once";
"alert.action.snooze" = "Snooze";
"settings.language.system" = "Follow System";
```

```text
// Sources/MemoryToastTool/Resources/zh-Hans.lproj/Localizable.strings
"menu.title" = "Memory Toast Tool";
"menu.status.normal" = "正常";
"menu.status.warning" = "警告";
"menu.status.critical" = "严重";
"menu.action.run_check" = "立即检测";
"menu.action.settings" = "设置";
"alert.title" = "内存压力过高";
"alert.action.quit_selected" = "退出所选";
"alert.action.force_quit_selected" = "强制退出所选";
"alert.action.ignore_once" = "忽略一次";
"alert.action.snooze" = "稍后提醒";
"settings.language.system" = "跟随系统";
```

- [ ] **Step 3: Implement the view models and SwiftUI views**

```swift
// Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift
import Foundation

@MainActor
@Observable
final class MenuBarViewModel {
    var latestSnapshot: MemorySnapshot?
    var latestReasons: [String] = []

    var statusText: String {
        switch latestSnapshot?.pressureLevel {
        case .critical: String(localized: "menu.status.critical", bundle: .module)
        case .warning: String(localized: "menu.status.warning", bundle: .module)
        default: String(localized: "menu.status.normal", bundle: .module)
        }
    }
}
```

```swift
// Sources/MemoryToastTool/UI/MenuBar/MenuBarView.swift
import SwiftUI

struct MenuBarView: View {
    @Bindable var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "menu.title", bundle: .module))
                .font(.headline)
            Text(viewModel.statusText)
                .foregroundStyle(.secondary)
            Divider()
            Button(String(localized: "menu.action.run_check", bundle: .module)) {}
            Button(String(localized: "menu.action.settings", bundle: .module)) {}
        }
        .padding(12)
        .frame(width: 280)
    }
}
```

```swift
// Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift
import SwiftUI

struct AlertPanelView: View {
    let title = String(localized: "alert.title", bundle: .module)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
            Button(String(localized: "alert.action.quit_selected", bundle: .module)) {}
            Button(String(localized: "alert.action.force_quit_selected", bundle: .module)) {}
                .disabled(true)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 280)
    }
}
```

```swift
// Sources/MemoryToastTool/UI/Settings/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Text(String(localized: "settings.language.system", bundle: .module))
        }
        .padding(20)
        .frame(width: 420)
    }
}
```

```swift
// Sources/MemoryToastTool/MemoryToastToolApp.swift
import SwiftUI

@main
struct MemoryToastToolApp: App {
    @State private var settingsStore = SettingsStore()
    @State private var menuBarViewModel = MenuBarViewModel()

    var body: some Scene {
        MenuBarExtra("Memory Toast Tool", systemImage: "memorychip") {
            MenuBarView(viewModel: menuBarViewModel)
        }
        Settings {
            SettingsView()
        }
        Window("Memory Alert", id: "memory-alert") {
            AlertPanelView()
        }
        .defaultSize(width: 480, height: 320)
    }
}
```

- [ ] **Step 4: Run full verification**

Run: `swift build && swift test`

Expected:
- `swift build` succeeds
- all tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift Sources/MemoryToastTool/UI/MenuBar/MenuBarView.swift Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift Sources/MemoryToastTool/UI/Settings/SettingsView.swift Sources/MemoryToastTool/Resources/en.lproj/Localizable.strings Sources/MemoryToastTool/Resources/zh-Hans.lproj/Localizable.strings Sources/MemoryToastTool/MemoryToastToolApp.swift Tests/MemoryToastToolTests/AlertSessionControllerTests.swift
git commit -m "feat: add menu bar ui and bilingual resources"
```

## Task 6: Replace placeholders with live macOS integrations and finish the first usable vertical slice

**Files:**
- Modify: `Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift`
- Modify: `Sources/MemoryToastTool/Monitoring/ProcessSampling.swift`
- Modify: `Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift`
- Modify: `Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift`
- Modify: `Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift`
- Modify: `Sources/MemoryToastTool/UI/Settings/SettingsView.swift`
- Modify: `Sources/MemoryToastTool/AlertSession/AlertSessionController.swift`

- [ ] **Step 1: Write the failing monitor integration test around real process memory mapping**

Add this test:

```swift
func testVisibleProcessesDropExitedApps() async throws {
    let controller = AlertSessionController(
        countdownSeconds: 10,
        appActionService: AppActionService(workspace: StubWorkspaceController()),
        relaunchService: AppRelaunchService()
    )

    controller.present(
        snapshot: MemorySnapshot(
            totalMemoryBytes: 10,
            usedMemoryBytes: 9,
            availableMemoryBytes: 1,
            swapUsedBytes: 3,
            pressureLevel: .critical,
            processes: [
                ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 5, isRunning: true),
                ProcessSample(pid: 8, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 4, isRunning: true)
            ]
        ),
        selectedPIDs: [7, 8]
    )

    await controller.requestQuitSelected()
    controller.refreshProcesses([
        ProcessSample(pid: 8, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 4, isRunning: true)
    ])

    XCTAssertEqual(controller.state.visibleProcesses.map(\.pid), [8])
}
```

- [ ] **Step 2: Implement the first real macOS samplers**

```swift
// Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift
import Foundation
import MachO

struct LiveSystemMemorySampler: SystemMemorySampling {
    func sampleSystemMemory() async throws -> SystemMemorySample {
        let total = ProcessInfo.processInfo.physicalMemory
        return SystemMemorySample(
            totalMemoryBytes: total,
            usedMemoryBytes: 0,
            availableMemoryBytes: total,
            swapUsedBytes: 0,
            pressureLevel: .normal
        )
    }
}
```

```swift
// Sources/MemoryToastTool/Monitoring/ProcessSampling.swift
import AppKit
import Foundation
import libproc

struct LiveProcessSampler: ProcessSampling {
    func sampleProcesses() async throws -> [ProcessSample] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            var usage = rusage_info_v2()
            let result = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { _ in
                    proc_pid_rusage(app.processIdentifier, RUSAGE_INFO_V2, &usage)
                }
            }
            guard result == 0 else {
                return ProcessSample(
                    pid: app.processIdentifier,
                    appName: app.localizedName ?? "Unknown",
                    bundleIdentifier: app.bundleIdentifier,
                    memoryBytes: 0,
                    isRunning: !app.isTerminated
                )
            }
            return ProcessSample(
                pid: app.processIdentifier,
                appName: app.localizedName ?? "Unknown",
                bundleIdentifier: app.bundleIdentifier,
                memoryBytes: usage.ri_resident_size,
                isRunning: !app.isTerminated
            )
        }
    }
}
```

- [ ] **Step 3: Finish the alert lifecycle and relaunch behavior**

Update `AlertSessionController` so that it:

```swift
// key behavior to add
// 1. tracks relaunch flags per pid
// 2. removes exited apps immediately on refresh
// 3. sets .completed when all selected pids are gone
// 4. exposes a countdownRemaining property for the UI
```

Concrete implementation requirement:

```swift
if state.selectedPIDs.allSatisfy({ pid in !alive.contains(pid) }) {
    state.phase = .completed
    state.forceQuitPIDs = []
}
```

- [ ] **Step 4: Wire live data into the menu bar and settings**

Implement these concrete additions:

```swift
// MenuBarViewModel requirements
// - own a MemoryMonitor
// - own a RuleEvaluator
// - load AppSettings from SettingsStore
// - expose refresh() async
// - publish rule reasons and snapshot status for the UI
```

```swift
// SettingsView requirements
// - TextField for detection interval seconds
// - TextField for default selected app count
// - TextField for relaunch delay seconds
// - Picker for language override: system / english / simplified chinese
```

- [ ] **Step 5: Run final verification**

Run: `swift build && swift test`

Expected:
- `swift build` succeeds
- all tests PASS
- launching with `swift run` opens the menu bar app without compile-time warnings

- [ ] **Step 6: Commit**

```bash
git add Sources/MemoryToastTool/Monitoring/SystemMemorySampling.swift Sources/MemoryToastTool/Monitoring/ProcessSampling.swift Sources/MemoryToastTool/ProcessControl/AppRelaunchService.swift Sources/MemoryToastTool/UI/MenuBar/MenuBarViewModel.swift Sources/MemoryToastTool/UI/Alert/AlertPanelView.swift Sources/MemoryToastTool/UI/Settings/SettingsView.swift Sources/MemoryToastTool/AlertSession/AlertSessionController.swift Tests/MemoryToastToolTests/MemoryMonitorTests.swift Tests/MemoryToastToolTests/AlertSessionControllerTests.swift
git commit -m "feat: ship first usable memory monitoring slice"
```

## Self-Review

### Spec Coverage

- Menu bar app shell: covered by Tasks 1 and 5
- Configurable detection interval and default selected count: covered by Tasks 1 and 6
- Multi-rule evaluation: covered by Task 2
- Monitoring pipeline and process list ordering: covered by Task 3
- Normal quit and force quit flow: covered by Task 4
- Single alert panel with live updates and close conditions: covered by Tasks 4 and 6
- Relaunch-after-quit: covered by Tasks 4 and 6
- Chinese/English localization: covered by Task 5
- Compile and test verification after each milestone: covered in every task

### Placeholder Scan

Checked the task steps for banned placeholder phrasing from the skill instructions.

Result: no task step relies on placeholder wording instead of concrete files, code, or commands.

### Type Consistency

- `AppSettings` is the persisted configuration type across Tasks 1, 5, and 6
- `MemorySnapshot`, `ProcessSample`, and `MemoryPressureLevel` are introduced in Task 2 and reused consistently later
- `AlertSessionController.state.phase` uses `AlertPhase` consistently across Tasks 4, 5, and 6
- `SettingsStore.load()` / `save(_:)` signatures remain stable after Task 1
