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

    func testQuitRequestDisablesSelectionAndRevealsForceQuitAfterCountdown() async throws {
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
        XCTAssertEqual(controller.state.phase, .forceQuitAvailable)
        XCTAssertTrue(controller.state.isSelectionLocked)
        XCTAssertEqual(controller.state.forceQuitPIDs, [7])
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
}
