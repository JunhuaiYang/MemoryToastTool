import XCTest
@testable import MemoryToastCore

@MainActor
final class AlertSessionControllerTests: XCTestCase {
    func testQuitRequestDisablesSelectionAndRevealsForceQuitAfterCountdown() async throws {
        let controller = AlertSessionController(
            countdownSeconds: 10,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
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

    func testCompletedSessionClosesWhenNoSelectedProcessesRemain() async throws {
        let controller = AlertSessionController(
            countdownSeconds: 10,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
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
        XCTAssertTrue(controller.state.visibleProcesses.isEmpty)
    }

    func testRefreshRemovesExitedProcessesImmediately() async throws {
        let controller = AlertSessionController(
            countdownSeconds: 10,
            appActionService: AppActionService(workspace: StubWorkspaceController()),
            relaunchService: AppRelaunchService(workspace: StubApplicationWorkspace())
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
}
