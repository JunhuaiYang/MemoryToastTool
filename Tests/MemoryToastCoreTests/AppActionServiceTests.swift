import XCTest
@testable import MemoryToastCore

final class AppActionServiceTests: XCTestCase {
    func testQuitDelegatesToWorkspaceController() async throws {
        let workspace = StubWorkspaceController()
        let service = AppActionService(workspace: workspace)

        try await service.requestQuit(bundleIdentifier: "com.apple.TextEdit")

        XCTAssertEqual(workspace.quitRequests, ["com.apple.TextEdit"])
    }
}
