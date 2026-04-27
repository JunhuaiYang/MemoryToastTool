# Process Tree And Main Window Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the GUI-only flat process list with a full process tree that aggregates child memory correctly, supports background processes and tree-aware selection, and turns Settings into the app's main window while simplifying the menu bar panel.

**Architecture:** Keep raw process sampling, tree construction, alert-session state, and SwiftUI presentation separate. Introduce a raw-process model plus a deterministic tree builder in `MemoryToastCore`, then adapt `AlertSessionController` and SwiftUI views to consume tree nodes instead of flat `ProcessSample` rows. Reuse the existing settings form as the main window content and expose alert presentation both automatically and manually.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Foundation, XCTest, Xcode project build + SwiftPM tests

---

## File Structure

### Core Model / Sampling Files

- Create: `Sources/MemoryToastCore/RawProcessSample.swift`
  - raw sampled process metadata including `pid`, `ppid`, name, bundle id, memory, and running state
- Create: `Sources/MemoryToastCore/ProcessTreeNode.swift`
  - UI-facing hierarchical tree node with aggregate memory and children
- Create: `Sources/MemoryToastCore/ProcessTreeBuilder.swift`
  - builds parent-child relationships, root detection, system-root stop rules, aggregate memory
- Modify: `Sources/MemoryToastCore/ProcessSampling.swift`
  - replace GUI-only enumeration with full-process sampling
- Modify: `Sources/MemoryToastCore/MemoryMonitor.swift`
  - build tree roots and flatten them into snapshots in descending aggregate-memory order
- Modify: `Sources/MemoryToastCore/MemorySnapshot.swift`
  - carry both ordered display rows and full tree roots for alert presentation
- Modify: `Sources/MemoryToastCore/ProcessSample.swift`
  - keep it as the per-node leaf/root display model, but add enough metadata for action routing and tree ownership

### Alert Session / Action Files

- Modify: `Sources/MemoryToastCore/AlertSessionState.swift`
  - add tree nodes, expand state, tri-state selection support, current snapshot summary, matched reasons
- Modify: `Sources/MemoryToastCore/AlertSessionController.swift`
  - upgrade from flat PID selection to hierarchical selection
- Modify: `Sources/MemoryToastCore/AppActionService.swift`
  - add process-level terminate / kill support for non-bundle background processes

### App UI Files

- Modify: `MemoryToastToolApp/AlertPanelView.swift`
  - render header metrics + matched reasons + tree list
- Modify: `MemoryToastToolApp/MenuBarView.swift`
  - remove matched reasons and top-process summaries; add settings entry
- Modify: `MemoryToastToolApp/MenuBarContainerView.swift`
  - allow manual alert presentation even without active matches; open the main window
- Modify: `MemoryToastToolApp/MenuBarViewModel.swift`
  - keep current memory summary + matched reasons for alert wiring, but stop presenting reasons/top-process summaries in menu UI
- Create: `MemoryToastToolApp/AppLifecycleController.swift`
  - manage Dock activation policy and reopen behavior for the main settings window
- Modify: `MemoryToastToolApp/SettingsView.swift`
  - add top action button to open alert panel
- Modify: `MemoryToastToolApp/MemoryToastToolApp.swift`
  - switch from `Settings {}` scene to a normal main `WindowGroup` for settings
- Modify: `MemoryToastToolApp/LocalizationSupport.swift`
  - add any new localized labels / formatting helpers if needed
- Modify: `MemoryToastToolApp/en.lproj/Localizable.strings`
- Modify: `MemoryToastToolApp/zh-Hans.lproj/Localizable.strings`
- Modify: `MemoryToastTool.xcodeproj/project.pbxproj`
  - only if new source files must be added to the Xcode target

### Tests

- Create: `Tests/MemoryToastCoreTests/ProcessTreeBuilderTests.swift`
- Modify: `Tests/MemoryToastCoreTests/MemoryMonitorTests.swift`
- Modify: `Tests/MemoryToastCoreTests/AppActionServiceTests.swift`
- Modify: `Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift`
- Modify: `Tests/MemoryToastCoreTests/TestDoubles.swift`

## Task 1: Add raw process sampling and tree aggregation

**Files:**
- Create: `Sources/MemoryToastCore/RawProcessSample.swift`
- Create: `Sources/MemoryToastCore/ProcessTreeNode.swift`
- Create: `Sources/MemoryToastCore/ProcessTreeBuilder.swift`
- Create: `Tests/MemoryToastCoreTests/ProcessTreeBuilderTests.swift`
- Modify: `Sources/MemoryToastCore/ProcessSample.swift`

- [ ] **Step 1: Write the failing tree-builder tests**

```swift
// Tests/MemoryToastCoreTests/ProcessTreeBuilderTests.swift
import XCTest
@testable import MemoryToastCore

final class ProcessTreeBuilderTests: XCTestCase {
    func testAggregatesChildrenIntoTopmostEligibleRoot() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 10, isRunning: true),
            RawProcessSample(pid: 100, ppid: 1, processName: "Google Chrome", bundleIdentifier: "com.google.Chrome", memoryBytes: 200, isRunning: true),
            RawProcessSample(pid: 101, ppid: 100, processName: "Google Chrome Helper", bundleIdentifier: nil, memoryBytes: 300, isRunning: true),
            RawProcessSample(pid: 102, ppid: 101, processName: "Google Chrome GPU", bundleIdentifier: nil, memoryBytes: 500, isRunning: true)
        ])

        XCTAssertEqual(roots.map(\.pid), [100])
        XCTAssertEqual(roots.first?.aggregateMemoryBytes, 1_000)
        XCTAssertEqual(roots.first?.children.map(\.pid), [101])
        XCTAssertEqual(roots.first?.children.first?.children.map(\.pid), [102])
    }

    func testOrphanBackgroundProcessBecomesStandaloneRoot() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 700, ppid: 1, processName: "worker", bundleIdentifier: nil, memoryBytes: 321, isRunning: true)
        ])

        XCTAssertEqual(roots.count, 1)
        XCTAssertEqual(roots[0].pid, 700)
        XCTAssertEqual(roots[0].aggregateMemoryBytes, 321)
    }

    func testStopsAtSystemRootBoundary() {
        let builder = ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])

        let roots = builder.buildTree(from: [
            RawProcessSample(pid: 0, ppid: 0, processName: "kernel_task", bundleIdentifier: nil, memoryBytes: 1, isRunning: true),
            RawProcessSample(pid: 10, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 1, isRunning: true),
            RawProcessSample(pid: 500, ppid: 10, processName: "daemon-a", bundleIdentifier: nil, memoryBytes: 111, isRunning: true),
            RawProcessSample(pid: 501, ppid: 500, processName: "daemon-b", bundleIdentifier: nil, memoryBytes: 222, isRunning: true)
        ])

        XCTAssertEqual(roots.map(\.pid), [500])
        XCTAssertEqual(roots[0].aggregateMemoryBytes, 333)
    }
}
```

- [ ] **Step 2: Run the tree-builder tests to verify they fail**

Run: `swift test --filter ProcessTreeBuilderTests`

Expected: FAIL with errors that `RawProcessSample`, `ProcessTreeNode`, and `ProcessTreeBuilder` do not exist yet.

- [ ] **Step 3: Add the raw-process model**

```swift
// Sources/MemoryToastCore/RawProcessSample.swift
import Foundation

public struct RawProcessSample: Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let processName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let isRunning: Bool

    public init(
        pid: Int32,
        ppid: Int32,
        processName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        isRunning: Bool
    ) {
        self.pid = pid
        self.ppid = ppid
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.isRunning = isRunning
    }
}
```

- [ ] **Step 4: Add the tree-node model**

```swift
// Sources/MemoryToastCore/ProcessTreeNode.swift
import Foundation

public struct ProcessTreeNode: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let parentPID: Int32?
    public let processName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let aggregateMemoryBytes: UInt64
    public let isRunning: Bool
    public let children: [ProcessTreeNode]

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        parentPID: Int32?,
        processName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        aggregateMemoryBytes: UInt64,
        isRunning: Bool,
        children: [ProcessTreeNode]
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.aggregateMemoryBytes = aggregateMemoryBytes
        self.isRunning = isRunning
        self.children = children
    }
}
```

- [ ] **Step 5: Implement the deterministic tree builder**

```swift
// Sources/MemoryToastCore/ProcessTreeBuilder.swift
import Foundation

public struct ProcessTreeBuilder: Sendable {
    public let systemRootNames: Set<String>

    public init(systemRootNames: Set<String> = ["launchd", "kernel_task"]) {
        self.systemRootNames = systemRootNames
    }

    public func buildTree(from processes: [RawProcessSample]) -> [ProcessTreeNode] {
        let live = processes.filter(\.isRunning)
        let byPID = Dictionary(uniqueKeysWithValues: live.map { ($0.pid, $0) })

        let childPIDsByParent = Dictionary(grouping: live, by: \.ppid)
            .mapValues { $0.map(\.pid).sorted() }

        let rootPIDs = live
            .filter { sample in
                guard let parent = byPID[sample.ppid] else {
                    return true
                }
                return systemRootNames.contains(parent.processName)
            }
            .map(\.pid)
            .sorted()

        return rootPIDs.compactMap { makeNode(pid: $0, parentPID: nil, byPID: byPID, childPIDsByParent: childPIDsByParent) }
            .sorted { $0.aggregateMemoryBytes > $1.aggregateMemoryBytes }
    }

    private func makeNode(
        pid: Int32,
        parentPID: Int32?,
        byPID: [Int32: RawProcessSample],
        childPIDsByParent: [Int32: [Int32]]
    ) -> ProcessTreeNode? {
        guard let sample = byPID[pid] else {
            return nil
        }

        let children = (childPIDsByParent[pid] ?? []).compactMap {
            makeNode(pid: $0, parentPID: pid, byPID: byPID, childPIDsByParent: childPIDsByParent)
        }

        let aggregate = sample.memoryBytes + children.reduce(0) { $0 + $1.aggregateMemoryBytes }

        return ProcessTreeNode(
            pid: sample.pid,
            parentPID: parentPID,
            processName: sample.processName,
            bundleIdentifier: sample.bundleIdentifier,
            memoryBytes: sample.memoryBytes,
            aggregateMemoryBytes: aggregate,
            isRunning: sample.isRunning,
            children: children
        )
    }
}
```

- [ ] **Step 6: Extend `ProcessSample` so each visible node can participate in tree display and action routing**

```swift
// Sources/MemoryToastCore/ProcessSample.swift
import Foundation

public struct ProcessSample: Equatable, Identifiable, Sendable {
    public let pid: Int32
    public let parentPID: Int32?
    public let appName: String
    public let bundleIdentifier: String?
    public let memoryBytes: UInt64
    public let aggregateMemoryBytes: UInt64
    public let isRunning: Bool
    public let childPIDs: [Int32]

    public var id: Int32 { pid }

    public init(
        pid: Int32,
        parentPID: Int32?,
        appName: String,
        bundleIdentifier: String?,
        memoryBytes: UInt64,
        aggregateMemoryBytes: UInt64,
        isRunning: Bool,
        childPIDs: [Int32]
    ) {
        self.pid = pid
        self.parentPID = parentPID
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.memoryBytes = memoryBytes
        self.aggregateMemoryBytes = aggregateMemoryBytes
        self.isRunning = isRunning
        self.childPIDs = childPIDs
    }
}
```

- [ ] **Step 7: Run the tree-builder tests to verify they pass**

Run: `swift test --filter ProcessTreeBuilderTests`

Expected: PASS with `3 tests, 0 failures`.

- [ ] **Step 8: Commit**

```bash
git add Sources/MemoryToastCore/RawProcessSample.swift Sources/MemoryToastCore/ProcessTreeNode.swift Sources/MemoryToastCore/ProcessTreeBuilder.swift Sources/MemoryToastCore/ProcessSample.swift Tests/MemoryToastCoreTests/ProcessTreeBuilderTests.swift
git commit -m "feat: add process tree aggregation"
```

## Task 2: Switch the monitor to full-process sampling and ordered tree snapshots

**Files:**
- Modify: `Sources/MemoryToastCore/ProcessSampling.swift`
- Modify: `Sources/MemoryToastCore/MemoryMonitor.swift`
- Modify: `Sources/MemoryToastCore/MemorySnapshot.swift`
- Modify: `Tests/MemoryToastCoreTests/MemoryMonitorTests.swift`

- [ ] **Step 1: Write the failing monitor test for aggregate-memory ordering**

```swift
// Tests/MemoryToastCoreTests/MemoryMonitorTests.swift
import XCTest
@testable import MemoryToastCore

final class MemoryMonitorTests: XCTestCase {
    func testMonitorReturnsRootsSortedByAggregateMemoryDescending() async throws {
        let monitor = MemoryMonitor(
            systemSampler: StubSystemMemorySampler(),
            processSampler: StubProcessSampler(rawProcesses: [
                RawProcessSample(pid: 1, ppid: 0, processName: "launchd", bundleIdentifier: nil, memoryBytes: 0, isRunning: true),
                RawProcessSample(pid: 10, ppid: 1, processName: "App A", bundleIdentifier: "a", memoryBytes: 100, isRunning: true),
                RawProcessSample(pid: 11, ppid: 10, processName: "App A Helper", bundleIdentifier: nil, memoryBytes: 700, isRunning: true),
                RawProcessSample(pid: 20, ppid: 1, processName: "App B", bundleIdentifier: "b", memoryBytes: 500, isRunning: true)
            ]),
            treeBuilder: ProcessTreeBuilder(systemRootNames: ["launchd", "kernel_task"])
        )

        let snapshot = try await monitor.sample()

        XCTAssertEqual(snapshot.processes.map(\.pid), [10, 20])
        XCTAssertEqual(snapshot.processes.map(\.aggregateMemoryBytes), [800, 500])
    }
}
```

- [ ] **Step 2: Run the monitor test to verify it fails**

Run: `swift test --filter MemoryMonitorTests`

Expected: FAIL because `MemoryMonitor` still expects flat `ProcessSampling` output and has no `treeBuilder`.

- [ ] **Step 3: Replace GUI-only sampling with raw process sampling**

```swift
// Sources/MemoryToastCore/ProcessSampling.swift
import AppKit
import Darwin
import Foundation

public protocol ProcessSampling: Sendable {
    func sampleProcesses() async throws -> [RawProcessSample]
}

public struct LiveProcessSampler: ProcessSampling {
    public init() {}

    public func sampleProcesses() async throws -> [RawProcessSample] {
        let workspaceApps = Dictionary(uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map {
            ($0.processIdentifier, $0)
        })

        let pids = allProcessIdentifiers()

        return pids.compactMap { pid in
            guard let kinfo = kinfo(for: pid) else {
                return nil
            }

            let app = workspaceApps[pid]
            let processName = app?.localizedName ?? commandName(from: kinfo)

            return RawProcessSample(
                pid: pid,
                ppid: kinfo.kp_eproc.e_ppid,
                processName: processName,
                bundleIdentifier: app?.bundleIdentifier,
                memoryBytes: residentMemoryBytes(for: pid),
                isRunning: true
            )
        }
    }
}
```

- [ ] **Step 4: Update `MemoryMonitor` to build and flatten tree roots**

```swift
// Sources/MemoryToastCore/MemorySnapshot.swift
public struct MemorySnapshot: Equatable, Sendable {
    public let totalMemoryBytes: UInt64
    public let usedMemoryBytes: UInt64
    public let availableMemoryBytes: UInt64
    public let swapUsedBytes: UInt64
    public let pressureLevel: MemoryPressureLevel
    public let processTreeRoots: [ProcessTreeNode]
    public let processes: [ProcessSample]
}
```

```swift
// Sources/MemoryToastCore/MemoryMonitor.swift
import Foundation

public struct MemoryMonitor: Sendable {
    public let systemSampler: SystemMemorySampling
    public let processSampler: ProcessSampling
    public let treeBuilder: ProcessTreeBuilder

    public init(
        systemSampler: SystemMemorySampling = LiveSystemMemorySampler(),
        processSampler: ProcessSampling = LiveProcessSampler(),
        treeBuilder: ProcessTreeBuilder = ProcessTreeBuilder()
    ) {
        self.systemSampler = systemSampler
        self.processSampler = processSampler
        self.treeBuilder = treeBuilder
    }

    public func sample() async throws -> MemorySnapshot {
        let system = try systemSampler.sampleSystemMemory()
        let rawProcesses = try await processSampler.sampleProcesses()
        let treeRoots = treeBuilder.buildTree(from: rawProcesses)
        let displayProcesses = treeRoots.map { root in
            ProcessSample(
                pid: root.pid,
                parentPID: root.parentPID,
                appName: root.processName,
                bundleIdentifier: root.bundleIdentifier,
                memoryBytes: root.memoryBytes,
                aggregateMemoryBytes: root.aggregateMemoryBytes,
                isRunning: root.isRunning,
                childPIDs: root.children.map(\.pid)
            )
        }

        return MemorySnapshot(
            totalMemoryBytes: system.totalMemoryBytes,
            usedMemoryBytes: system.usedMemoryBytes,
            availableMemoryBytes: system.availableMemoryBytes,
            swapUsedBytes: system.swapUsedBytes,
            pressureLevel: system.pressureLevel,
            processTreeRoots: treeRoots,
            processes: displayProcesses
        )
    }
}
```

- [ ] **Step 5: Update test doubles to return raw processes**

```swift
// Tests/MemoryToastCoreTests/TestDoubles.swift
struct StubProcessSampler: ProcessSampling {
    let rawProcesses: [RawProcessSample]

    func sampleProcesses() async throws -> [RawProcessSample] {
        rawProcesses
    }
}
```

- [ ] **Step 6: Run the monitor tests to verify they pass**

Run: `swift test --filter MemoryMonitorTests`

Expected: PASS with the new aggregate-memory ordering assertion.

- [ ] **Step 7: Commit**

```bash
git add Sources/MemoryToastCore/ProcessSampling.swift Sources/MemoryToastCore/MemoryMonitor.swift Sources/MemoryToastCore/MemorySnapshot.swift Tests/MemoryToastCoreTests/MemoryMonitorTests.swift Tests/MemoryToastCoreTests/TestDoubles.swift
git commit -m "feat: monitor full process hierarchy"
```

## Task 3: Add process-level actions and tree-aware alert-session state

**Files:**
- Modify: `Sources/MemoryToastCore/AppActionService.swift`
- Modify: `Sources/MemoryToastCore/AlertSessionState.swift`
- Modify: `Sources/MemoryToastCore/AlertSessionController.swift`
- Modify: `Tests/MemoryToastCoreTests/AppActionServiceTests.swift`
- Modify: `Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift`
- Modify: `Tests/MemoryToastCoreTests/TestDoubles.swift`

- [ ] **Step 1: Write failing tests for background-process actions and parent-child selection**

```swift
// Tests/MemoryToastCoreTests/AppActionServiceTests.swift
func testTerminateProcessDelegatesToProcessController() async throws {
    let processController = StubProcessController()
    let service = AppActionService(
        workspace: StubWorkspaceController(),
        processController: processController
    )

    try await service.requestQuit(pid: 900, bundleIdentifier: nil)

    XCTAssertEqual(processController.terminateRequests, [900])
}
```

```swift
// Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift
func testSelectingParentSelectsAllDescendants() async throws {
    let controller = makeController()

    controller.present(snapshot: makeTreeSnapshot(), selectedPIDs: [100])

    XCTAssertEqual(Set(controller.state.selectedPIDs), [100, 101, 102])
}

func testChildOnlySelectionMarksParentPartiallySelected() async throws {
    let controller = makeController()

    controller.present(snapshot: makeTreeSnapshot(), selectedPIDs: [])
    controller.setSelected(pid: 102, isSelected: true)

    XCTAssertEqual(controller.selectionState(for: 100), .partiallySelected)
}
```

- [ ] **Step 2: Run the alert-session and action tests to verify they fail**

Run: `swift test --filter AppActionServiceTests`

Expected: FAIL because process-level terminate / kill does not exist.

Run: `swift test --filter AlertSessionControllerTests`

Expected: FAIL because hierarchical selection helpers do not exist.

- [ ] **Step 3: Add process-level terminate / kill support**

```swift
// Sources/MemoryToastCore/AppActionService.swift
import AppKit
import Darwin
import Foundation

public protocol ProcessControlling: Sendable {
    func terminate(pid: Int32) async throws
    func kill(pid: Int32) async throws
}

public struct LiveProcessController: ProcessControlling {
    public init() {}

    public func terminate(pid: Int32) async throws {
        _ = Darwin.kill(pid, SIGTERM)
    }

    public func kill(pid: Int32) async throws {
        _ = Darwin.kill(pid, SIGKILL)
    }
}

public struct AppActionService: Sendable {
    public let workspace: WorkspaceControlling
    public let processController: ProcessControlling

    public init(
        workspace: WorkspaceControlling = LiveWorkspaceController(),
        processController: ProcessControlling = LiveProcessController()
    ) {
        self.workspace = workspace
        self.processController = processController
    }

    public func requestQuit(pid: Int32, bundleIdentifier: String?) async throws {
        if let bundleIdentifier {
            try await workspace.requestQuit(bundleIdentifier: bundleIdentifier)
        } else {
            try await processController.terminate(pid: pid)
        }
    }

    public func forceQuit(pid: Int32, bundleIdentifier: String?) async throws {
        if let bundleIdentifier {
            try await workspace.forceQuit(bundleIdentifier: bundleIdentifier)
        } else {
            try await processController.kill(pid: pid)
        }
    }
}
```

- [ ] **Step 4: Expand alert session state to support tree data and header data**

```swift
// Sources/MemoryToastCore/AlertSessionState.swift
import Foundation

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
}
```

- [ ] **Step 5: Implement tree-aware selection in `AlertSessionController`**

```swift
// Sources/MemoryToastCore/AlertSessionController.swift
@MainActor
public final class AlertSessionController: ObservableObject {
    public func present(
        snapshot: MemorySnapshot,
        treeRoots: [ProcessTreeNode],
        matchedReasons: [TriggeredRuleReason],
        selectedPIDs: [Int32]
    ) {
        let expanded = Set<Int32>()
        let selected = expandSelectionToDescendants(selectedPIDs, in: treeRoots)

        state.phase = .presenting
        state.snapshot = snapshot
        state.matchedReasons = matchedReasons
        state.visibleTreeRoots = treeRoots
        state.visibleProcesses = flatten(treeRoots)
        state.expandedPIDs = expanded
        state.selectedPIDs = selected
        state.originalSelectedPIDs = selected
        state.forceQuitPIDs = []
        state.forceQuitRequestedPIDs = []
        state.relaunchAfterQuitPIDs = []
        state.isSelectionLocked = false
        state.countdownRemaining = countdownSeconds
        state.countdownTotalSeconds = countdownSeconds
    }

    public func setSelected(pid: Int32, isSelected: Bool) {
        guard !state.isSelectionLocked else { return }

        let affected = descendantPIDs(of: pid, in: state.visibleTreeRoots)
        var next = Set(state.selectedPIDs)

        if isSelected {
            next.formUnion(affected)
        } else {
            next.subtract(affected)
        }

        state.selectedPIDs = orderedPIDs(Array(next), within: state.visibleProcesses)
    }

    public func selectionState(for pid: Int32) -> TreeSelectionState {
        let descendants = descendantPIDs(of: pid, in: state.visibleTreeRoots)
        let selected = descendants.filter { state.selectedPIDs.contains($0) }

        if selected.isEmpty { return .unselected }
        if selected.count == descendants.count { return .selected }
        return .partiallySelected
    }
}
```

- [ ] **Step 6: Route quit / force-quit through PID-aware actions**

```swift
// inside AlertSessionController.requestQuitSelected()
for process in state.visibleProcesses where state.selectedPIDs.contains(process.pid) {
    try? await appActionService.requestQuit(pid: process.pid, bundleIdentifier: process.bundleIdentifier)
}

// inside AlertSessionController.forceQuitSelected()
for process in state.visibleProcesses where state.forceQuitPIDs.contains(process.pid) {
    try? await appActionService.forceQuit(pid: process.pid, bundleIdentifier: process.bundleIdentifier)
}
```

- [ ] **Step 7: Run the action and alert-session tests to verify they pass**

Run: `swift test --filter AppActionServiceTests`

Expected: PASS with process terminate / kill coverage.

Run: `swift test --filter AlertSessionControllerTests`

Expected: PASS with tree-selection coverage and existing countdown behavior still green.

- [ ] **Step 8: Commit**

```bash
git add Sources/MemoryToastCore/AppActionService.swift Sources/MemoryToastCore/AlertSessionState.swift Sources/MemoryToastCore/AlertSessionController.swift Tests/MemoryToastCoreTests/AppActionServiceTests.swift Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift Tests/MemoryToastCoreTests/TestDoubles.swift
git commit -m "feat: support tree-aware alert actions"
```

## Task 4: Convert the alert panel to a live tree with header metrics and matched reasons

**Files:**
- Modify: `MemoryToastToolApp/AlertPanelView.swift`
- Modify: `MemoryToastToolApp/LocalizationSupport.swift`
- Modify: `MemoryToastToolApp/en.lproj/Localizable.strings`
- Modify: `MemoryToastToolApp/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Add a failing UI-level test for controller header state**

```swift
// Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift
func testPresentStoresSnapshotAndMatchedReasonsForHeaderDisplay() async throws {
    let controller = makeController()
    let snapshot = makeTreeSnapshot()

    controller.present(
        snapshot: snapshot,
        treeRoots: makeTreeRoots(),
        matchedReasons: [.availableMemoryBelow(bytes: 1_000)],
        selectedPIDs: [100]
    )

    XCTAssertEqual(controller.state.snapshot?.availableMemoryBytes, 1)
    XCTAssertEqual(controller.state.matchedReasons, [.availableMemoryBelow(bytes: 1_000)])
}
```

- [ ] **Step 2: Run the focused alert-session test to verify it fails if not already covered**

Run: `swift test --filter AlertSessionControllerTests/testPresentStoresSnapshotAndMatchedReasonsForHeaderDisplay`

Expected: FAIL until `present` carries snapshot + reasons.

- [ ] **Step 3: Render the alert header summary above the tree**

```swift
// MemoryToastToolApp/AlertPanelView.swift
VStack(alignment: .leading, spacing: 12) {
    if let snapshot = controller.state.snapshot {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                metricCell(title: localizedString("menu.metric.used", language: language),
                           value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.usedMemoryBytes), countStyle: .memory))
                metricCell(title: localizedString("menu.metric.available", language: language),
                           value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.availableMemoryBytes), countStyle: .memory))
            }
            GridRow {
                metricCell(title: localizedString("menu.metric.swap", language: language),
                           value: ByteCountFormatter.string(fromByteCount: Int64(snapshot.swapUsedBytes), countStyle: .memory))
                metricCell(title: localizedString("menu.metric.pressure", language: language),
                           value: localizedPressureLevel(snapshot.pressureLevel, language: language))
            }
        }
    }

    if !controller.state.matchedReasons.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizedString("menu.reasons", language: language))
                .font(.subheadline.weight(.semibold))

            ForEach(Array(controller.state.matchedReasons.enumerated()), id: \.offset) { _, reason in
                Text(localizedRuleReason(reason, language: language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
```

- [ ] **Step 4: Replace the flat list with a recursive tree list**

```swift
// MemoryToastToolApp/AlertPanelView.swift
ForEach(controller.state.visibleTreeRoots) { root in
    ProcessTreeRow(
        node: root,
        depth: 0,
        controller: controller,
        settings: $settings,
        language: language,
        onSaveSettings: onSaveSettings
    )
}
```

```swift
private struct ProcessTreeRow: View {
    let node: ProcessTreeNode
    let depth: Int
    @ObservedObject var controller: AlertSessionController
    @Binding var settings: AppSettings
    let language: AppLanguage?
    let onSaveSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    controller.toggleExpanded(pid: node.pid)
                } label: {
                    Image(systemName: node.children.isEmpty ? "circle.fill" : (controller.isExpanded(pid: node.pid) ? "chevron.down" : "chevron.right"))
                }
                .buttonStyle(.plain)

                Toggle("", isOn: Binding(
                    get: { controller.selectionState(for: node.pid) == .selected },
                    set: { controller.setSelected(pid: node.pid, isSelected: $0) }
                ))
                .toggleStyle(.checkbox)

                Text(node.processName)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(node.aggregateMemoryBytes), countStyle: .memory))
                    .monospacedDigit()
            }
            .padding(.leading, CGFloat(depth) * 16)

            if controller.isExpanded(pid: node.pid) {
                ForEach(node.children) { child in
                    ProcessTreeRow(
                        node: child,
                        depth: depth + 1,
                        controller: controller,
                        settings: $settings,
                        language: language,
                        onSaveSettings: onSaveSettings
                    )
                }
            }
        }
    }
}
```

- [ ] **Step 5: Add localization strings for new settings/alert labels if needed**

```text
// MemoryToastToolApp/en.lproj/Localizable.strings
"menu.action.open_settings" = "Open Settings";
"settings.action.open_alert" = "Open Alert Panel";

// MemoryToastToolApp/zh-Hans.lproj/Localizable.strings
"menu.action.open_settings" = "打开设置";
"settings.action.open_alert" = "打开告警面板";
```

- [ ] **Step 6: Run focused tests plus a full package pass**

Run: `swift test --filter AlertSessionControllerTests`

Expected: PASS with header-state coverage and no countdown regressions.

Run: `swift test`

Expected: PASS, `0 failures`.

- [ ] **Step 7: Commit**

```bash
git add MemoryToastToolApp/AlertPanelView.swift MemoryToastToolApp/LocalizationSupport.swift MemoryToastToolApp/en.lproj/Localizable.strings MemoryToastToolApp/zh-Hans.lproj/Localizable.strings Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift
git commit -m "feat: render alert process tree"
```

## Task 5: Turn Settings into the main window and simplify the menu bar panel

**Files:**
- Create: `MemoryToastToolApp/AppLifecycleController.swift`
- Modify: `MemoryToastToolApp/MemoryToastToolApp.swift`
- Modify: `MemoryToastToolApp/MenuBarContainerView.swift`
- Modify: `MemoryToastToolApp/MenuBarView.swift`
- Modify: `MemoryToastToolApp/MenuBarViewModel.swift`
- Modify: `MemoryToastToolApp/SettingsView.swift`
- Modify: `MemoryToastToolApp/en.lproj/Localizable.strings`
- Modify: `MemoryToastToolApp/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Add a failing controller/menu test for manual alert presentation**

```swift
// Tests/MemoryToastCoreTests/AlertSessionControllerTests.swift
func testManualPresentCanShowTreeWithoutMatchedReasons() async throws {
    let controller = makeController()
    let snapshot = makeTreeSnapshot()

    controller.present(
        snapshot: snapshot,
        treeRoots: makeTreeRoots(),
        matchedReasons: [],
        selectedPIDs: []
    )

    XCTAssertEqual(controller.state.phase, .presenting)
    XCTAssertEqual(controller.state.visibleTreeRoots.map(\.pid), [100])
}
```

- [ ] **Step 2: Run the focused test to verify the manual-present path is covered**

Run: `swift test --filter AlertSessionControllerTests/testManualPresentCanShowTreeWithoutMatchedReasons`

Expected: PASS once the tree-aware `present` API exists.

- [ ] **Step 3: Convert Settings into the main app window**

```swift
// MemoryToastToolApp/MemoryToastToolApp.swift
@NSApplicationDelegateAdaptor(AppLifecycleController.self) private var appLifecycleController

var body: some Scene {
    WindowGroup(id: "main-window") {
        SettingsView(
            settings: $settings,
            onSave: saveSettings,
            onOpenAlert: {
                menuBarViewModel.refreshAndBuildAlertPayload()
            }
        )
    }
    .defaultSize(width: 480, height: 520)

    MenuBarExtra(localizedString("menu.title", language: settings.languageOverride), systemImage: "memorychip") {
        MenuBarContainerView(
            viewModel: menuBarViewModel,
            alertSessionController: alertSessionController,
            settings: $settings,
            isIgnoringCurrentIncident: $isIgnoringCurrentIncident,
            onSaveSettings: saveSettings
        )
    }
}
```

- [ ] **Step 4: Add an AppKit lifecycle controller for Dock visibility and reopen behavior**

```swift
// MemoryToastToolApp/AppLifecycleController.swift
import AppKit

final class AppLifecycleController: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func mainWindowDidOpen() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func mainWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 5: Add the menu-bar settings action and remove reasons/top-apps from the menu UI**

```swift
// MemoryToastToolApp/MenuBarView.swift
VStack(alignment: .leading, spacing: 12) {
    Text(localizedString("menu.title", language: language))
        .font(.headline)

    Text(localizedPressureLevel(viewModel.statusLevel, language: language))
        .foregroundStyle(.secondary)

    if let snapshot = viewModel.latestSnapshot {
        metricGrid(snapshot: snapshot)
    } else {
        Text(localizedString("menu.loading", language: language))
            .foregroundStyle(.secondary)
    }

    Divider()

    HStack {
        Button(localizedString("menu.action.run_check", language: language), action: onRefresh)
        Button(localizedString("menu.action.open_alert", language: language), action: onOpenAlert)
    }

    Button(localizedString("menu.action.open_settings", language: language), action: onOpenSettings)
    Button(localizedString("menu.action.open_guide", language: language), action: onOpenGuide)
}
```

- [ ] **Step 6: Extend `MenuBarViewModel` with tree roots and a manual-alert payload**

```swift
// MemoryToastToolApp/MenuBarViewModel.swift
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var latestSnapshot: MemorySnapshot?
    @Published var latestReasons: [TriggeredRuleReason] = []
    @Published var latestTreeRoots: [ProcessTreeNode] = []

    var latestDisplayProcesses: [ProcessSample] {
        latestSnapshot?.processes ?? []
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let snapshot = try await monitor.sample()
            latestSnapshot = snapshot
            latestTreeRoots = snapshot.processTreeRoots
            latestReasons = ruleEvaluator.evaluate(snapshot: snapshot, rules: activeRules).matches
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
```

- [ ] **Step 7: Add the Settings top button for manual alert opening**

```swift
// MemoryToastToolApp/SettingsView.swift
struct SettingsView: View {
    @Binding var settings: AppSettings
    let onSave: () -> Void
    let onOpenAlert: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(localizedString("settings.action.open_alert", language: language), action: onOpenAlert)
                Spacer()
            }

            Form {
                TextField(localizedString("settings.interval", language: language), value: $settings.detectionIntervalSeconds, formatter: numberFormatter)
                // keep the rest of the existing form unchanged
            }
        }
        .padding(20)
        .frame(width: 440, height: 520)
    }
}
```

- [ ] **Step 8: Wire manual alert presentation from menu/settings even without active rule matches**

```swift
// MemoryToastToolApp/MenuBarContainerView.swift
private func presentCurrentAlertPanel() {
    Task {
        guard let (snapshot, treeRoots, matchedReasons) = await viewModel.refreshAndBuildAlertPayload() else {
            return
        }

        alertSessionController.present(
            snapshot: snapshot,
            treeRoots: treeRoots,
            matchedReasons: matchedReasons,
            selectedPIDs: selectionPlanner.selectDefaultPIDs(
                from: viewModel.latestDisplayProcesses,
                count: settings.defaultSelectedAppCount,
                ignoredBundleIdentifiers: settings.ignoredBundleIdentifiers
            )
        )
        presentAlertWindow()
    }
}
```

- [ ] **Step 9: Notify the lifecycle controller when the main window opens and closes**

```swift
// MemoryToastToolApp/MemoryToastToolApp.swift
WindowGroup(id: "main-window") {
    SettingsView(
        settings: $settings,
        onSave: saveSettings,
        onOpenAlert: {
            presentCurrentAlertPanel()
        }
    )
    .onAppear {
        appLifecycleController.mainWindowDidOpen()
    }
    .onDisappear {
        appLifecycleController.mainWindowDidClose()
    }
}
```

- [ ] **Step 10: Run a full package pass**

Run: `swift test`

Expected: PASS, `0 failures`.

- [ ] **Step 11: Commit**

```bash
git add MemoryToastToolApp/AppLifecycleController.swift MemoryToastToolApp/MemoryToastToolApp.swift MemoryToastToolApp/MenuBarContainerView.swift MemoryToastToolApp/MenuBarView.swift MemoryToastToolApp/MenuBarViewModel.swift MemoryToastToolApp/SettingsView.swift MemoryToastToolApp/en.lproj/Localizable.strings MemoryToastToolApp/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add main settings window"
```

## Task 6: Final verification, Xcode integration, and documentation sync

**Files:**
- Modify: `MemoryToastTool.xcodeproj/project.pbxproj` (if new source files are not yet part of the app target)
- Modify: `README.md`
- Modify: `AGENT.md`

- [ ] **Step 1: Add any new source files to the Xcode project if needed**

```text
Ensure these files are in the app target build phase if they were created:
- Sources/MemoryToastCore/RawProcessSample.swift
- Sources/MemoryToastCore/ProcessTreeNode.swift
- Sources/MemoryToastCore/ProcessTreeBuilder.swift
```

- [ ] **Step 2: Update README to match the new tree and main-window behavior**

```markdown
Update the README sections so they explicitly say:
- background processes are included
- memory is shown in a collapsible process tree
- child memory is aggregated into root totals
- Settings is the app's main window
- the menu bar panel shows current memory info only
- the alert panel shows current memory info plus matched rules
```

- [ ] **Step 3: Update AGENT.md to lock the new product contract**

```markdown
Update AGENT.md so it reflects:
- tree-based alert panel
- background-process support
- parent-child selection behavior
- main-window settings behavior
- alert-header/menu-bar information split
```

- [ ] **Step 4: Run full package verification**

Run:

```bash
HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.cache/clang swift test --scratch-path .swiftpm-cache
```

Expected: PASS with `0 failures`.

- [ ] **Step 5: Run native app build verification**

Run:

```bash
xcodebuild -project MemoryToastTool.xcodeproj -scheme MemoryToastTool -derivedDataPath .derived-data -destination 'platform=macOS,arch=arm64' build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add MemoryToastTool.xcodeproj/project.pbxproj README.md AGENT.md
git commit -m "docs: sync process tree behavior"
```
