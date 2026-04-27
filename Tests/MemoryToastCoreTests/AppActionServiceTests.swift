import XCTest
@testable import MemoryToastCore

final class AppActionServiceTests: XCTestCase {
    func testQuitDelegatesToWorkspaceController() async throws {
        let workspace = StubWorkspaceController()
        let service = AppActionService(workspace: workspace)

        try await service.requestQuit(bundleIdentifier: "com.apple.TextEdit")

        XCTAssertEqual(workspace.quitRequests, ["com.apple.TextEdit"])
    }

    func testTerminateProcessDelegatesToProcessController() async throws {
        let processController = StubProcessController()
        let service = AppActionService(
            workspace: StubWorkspaceController(),
            processController: processController
        )

        try await service.requestQuit(pid: 900, bundleIdentifier: nil)

        XCTAssertEqual(processController.terminateRequests, [900])
    }

    func testKillProcessDelegatesToProcessController() async throws {
        let processController = StubProcessController()
        let service = AppActionService(
            workspace: StubWorkspaceController(),
            processController: processController
        )

        try await service.forceQuit(pid: 901, bundleIdentifier: nil)

        XCTAssertEqual(processController.killRequests, [901])
    }
}
