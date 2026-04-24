import Foundation
@testable import MemoryToastCore

final class StubWorkspaceController: @unchecked Sendable, WorkspaceControlling {
    var quitRequests: [String] = []
    var forceQuitRequests: [String] = []

    func requestQuit(bundleIdentifier: String) async throws {
        quitRequests.append(bundleIdentifier)
    }

    func forceQuit(bundleIdentifier: String) async throws {
        forceQuitRequests.append(bundleIdentifier)
    }
}

final class StubApplicationWorkspace: @unchecked Sendable, ApplicationWorkspace {
    private(set) var openedApplicationURLs: [URL] = []

    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        URL(fileURLWithPath: "/Applications/\(bundleIdentifier).app")
    }

    func openApplication(at url: URL) {
        openedApplicationURLs.append(url)
    }
}
