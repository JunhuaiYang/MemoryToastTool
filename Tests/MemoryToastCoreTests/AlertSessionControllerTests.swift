import XCTest
@testable import MemoryToastCore

@MainActor
final class AlertSessionControllerTests: XCTestCase {
    func testSelectionCanBeEditedBeforeQuitRequest() async throws {
        let controller = makeController()

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8])
        controller.setSelected(pid: 8, isSelected: false)
        controller.setSelected(pid: 9, isSelected: true)

        XCTAssertEqual(controller.state.selectedPIDs, [7, 9])
    }

    func testSelectionChangesAreIgnoredAfterQuitRequest() async throws {
        let controller = makeController()

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8])
        await controller.requestQuitSelected()
        controller.setSelected(pid: 8, isSelected: false)

        XCTAssertEqual(controller.state.selectedPIDs, [7, 8])
        XCTAssertTrue(controller.state.isSelectionLocked)
    }

    func testRelaunchFlagsCanBeChangedBeforeQuitAndLockAfterRequest() async throws {
        let controller = makeController()

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7])
        controller.setRelaunchAfterQuit(pid: 7, isEnabled: true)
        XCTAssertEqual(controller.state.relaunchAfterQuitPIDs, [7])

        await controller.requestQuitSelected()
        controller.setRelaunchAfterQuit(pid: 8, isEnabled: true)

        XCTAssertEqual(controller.state.relaunchAfterQuitPIDs, [7])
    }

    func testQuitRequestDisablesSelectionAndPromptsForceQuitAfterCountdown() async throws {
        let workspace = StubWorkspaceController()
        let controller = AlertSessionController(
            countdownSeconds: 10,
            relaunchDelaySeconds: 5,
            appActionService: AppActionService(workspace: workspace),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
        )

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8])

        await controller.requestQuitSelected()
        controller.refreshProcesses([
            ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 6, isRunning: true)
        ])
        await controller.finishCountdown()

        XCTAssertEqual(workspace.quitRequests, ["chrome", "slack"])
        XCTAssertEqual(controller.state.phase, .waitingForQuitCompletion)
        XCTAssertTrue(controller.state.isSelectionLocked)
        XCTAssertEqual(controller.state.forceQuitPIDs, [7])
        XCTAssertTrue(controller.state.isForceQuitConfirmationPresented)
    }

    func testForceQuitOnlyTargetsOriginallySelectedProcessesStillAlive() async throws {
        let workspace = StubWorkspaceController()
        let controller = AlertSessionController(
            countdownSeconds: 10,
            relaunchDelaySeconds: 5,
            appActionService: AppActionService(workspace: workspace),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
        )

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8])
        await controller.requestQuitSelected()
        controller.refreshProcesses([
            ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 6, isRunning: true),
            ProcessSample(pid: 9, appName: "Arc", bundleIdentifier: "arc", memoryBytes: 4, isRunning: true)
        ])
        await controller.finishCountdown()
        await controller.forceQuitSelected()

        XCTAssertEqual(workspace.forceQuitRequests, ["chrome"])
    }

    func testContinueWaitingDismissesForceQuitPromptButKeepsSessionActive() async throws {
        let controller = makeController()

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8])
        await controller.requestQuitSelected()
        controller.refreshProcesses([
            ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 6, isRunning: true)
        ])
        await controller.finishCountdown()
        controller.continueWaitingAfterForceQuitPrompt()

        XCTAssertEqual(controller.state.phase, .waitingForQuitCompletion)
        XCTAssertFalse(controller.state.isForceQuitConfirmationPresented)
        XCTAssertEqual(controller.state.forceQuitPIDs, [7])
    }

    func testCompletedSessionClosesWhenNoSelectedProcessesRemain() async throws {
        let workspace = StubApplicationWorkspace()
        let controller = AlertSessionController(
            countdownSeconds: 10,
            relaunchDelaySeconds: 0,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService(workspace: workspace)
        )

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7])
        controller.setRelaunchAfterQuit(pid: 7, isEnabled: true)

        await controller.requestQuitSelected()
        controller.refreshProcesses([])
        await Task.yield()

        XCTAssertEqual(controller.state.phase, .completed)
        XCTAssertTrue(controller.state.visibleProcesses.isEmpty)
        XCTAssertEqual(workspace.openedApplicationURLs.map(\.lastPathComponent), ["chrome.app"])
    }

    func testRefreshRemovesExitedProcessesImmediately() async throws {
        let controller = makeController()

        controller.present(snapshot: makeSnapshot(), selectedPIDs: [7, 8, 9])
        await controller.requestQuitSelected()
        controller.refreshProcesses([
            ProcessSample(pid: 8, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 4, isRunning: true),
            ProcessSample(pid: 9, appName: "Arc", bundleIdentifier: "arc", memoryBytes: 3, isRunning: true)
        ])

        XCTAssertEqual(controller.state.visibleProcesses.map(\.pid), [8, 9])
    }

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

    func testPresentStoresSnapshotAndMatchedReasonsForHeaderDisplay() async throws {
        let controller = makeController()
        let snapshot = makeTreeSnapshot()
        let reasons: [TriggeredRuleReason] = [.availableMemoryBelow(bytes: 1_000)]

        controller.present(snapshot: snapshot, matchedReasons: reasons, selectedPIDs: [100])

        XCTAssertEqual(controller.state.snapshot, snapshot)
        XCTAssertEqual(controller.state.matchedReasons, reasons)
    }

    func testSelectedRootsArePinnedAheadOfUnselectedRoots() async throws {
        let controller = makeController()

        controller.present(snapshot: makeMultiRootSnapshot(), selectedPIDs: [100])

        XCTAssertEqual(controller.state.visibleTreeRoots.map(\.pid), [100, 200])
        XCTAssertEqual(controller.state.visibleProcesses.prefix(2).map(\.pid), [100, 200])
    }

    private func makeController() -> AlertSessionController {
        AlertSessionController(
            countdownSeconds: 10,
            relaunchDelaySeconds: 5,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
        )
    }

    private func makeSnapshot() -> MemorySnapshot {
        MemorySnapshot(
            totalMemoryBytes: 10,
            usedMemoryBytes: 9,
            availableMemoryBytes: 1,
            swapUsedBytes: 3,
            pressureLevel: .critical,
            processes: [
                ProcessSample(pid: 7, appName: "Chrome", bundleIdentifier: "chrome", memoryBytes: 6, isRunning: true),
                ProcessSample(pid: 8, appName: "Slack", bundleIdentifier: "slack", memoryBytes: 5, isRunning: true),
                ProcessSample(pid: 9, appName: "Arc", bundleIdentifier: "arc", memoryBytes: 4, isRunning: true)
            ]
        )
    }

    private func makeTreeSnapshot() -> MemorySnapshot {
        let child = ProcessTreeNode(
            pid: 102,
            parentPID: 101,
            processName: "Chrome GPU",
            bundleIdentifier: nil,
            memoryBytes: 3,
            aggregateMemoryBytes: 3,
            isRunning: true,
            children: []
        )
        let helper = ProcessTreeNode(
            pid: 101,
            parentPID: 100,
            processName: "Chrome Helper",
            bundleIdentifier: nil,
            memoryBytes: 4,
            aggregateMemoryBytes: 7,
            isRunning: true,
            children: [child]
        )
        let root = ProcessTreeNode(
            pid: 100,
            parentPID: nil,
            processName: "Chrome",
            bundleIdentifier: "chrome",
            memoryBytes: 5,
            aggregateMemoryBytes: 12,
            isRunning: true,
            children: [helper]
        )

        return MemorySnapshot(
            totalMemoryBytes: 20,
            usedMemoryBytes: 12,
            availableMemoryBytes: 8,
            swapUsedBytes: 1,
            pressureLevel: .warning,
            processTreeRoots: [root],
            processes: [
                ProcessSample(
                    pid: 100,
                    appName: "Chrome",
                    bundleIdentifier: "chrome",
                    memoryBytes: 5,
                    aggregateMemoryBytes: 12,
                    isRunning: true,
                    childPIDs: [101]
                )
            ]
        )
    }

    private func makeMultiRootSnapshot() -> MemorySnapshot {
        let lighterSelectedRoot = ProcessTreeNode(
            pid: 100,
            parentPID: nil,
            processName: "Selected App",
            bundleIdentifier: "selected",
            memoryBytes: 4,
            aggregateMemoryBytes: 4,
            isRunning: true,
            children: []
        )
        let heavierUnselectedRoot = ProcessTreeNode(
            pid: 200,
            parentPID: nil,
            processName: "Background App",
            bundleIdentifier: "background",
            memoryBytes: 10,
            aggregateMemoryBytes: 10,
            isRunning: true,
            children: []
        )

        return MemorySnapshot(
            totalMemoryBytes: 20,
            usedMemoryBytes: 12,
            availableMemoryBytes: 8,
            swapUsedBytes: 1,
            pressureLevel: .warning,
            processTreeRoots: [heavierUnselectedRoot, lighterSelectedRoot],
            processes: [
                ProcessSample(pid: 200, appName: "Background App", bundleIdentifier: "background", memoryBytes: 10, aggregateMemoryBytes: 10, isRunning: true),
                ProcessSample(pid: 100, appName: "Selected App", bundleIdentifier: "selected", memoryBytes: 4, aggregateMemoryBytes: 4, isRunning: true)
            ]
        )
    }
}
