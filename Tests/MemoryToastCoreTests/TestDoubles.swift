import Foundation
@testable import MemoryToastCore

struct StubProcessSampler: ProcessSampling {
    let rawProcesses: [RawProcessSample]

    func sampleProcesses() async throws -> [RawProcessSample] {
        rawProcesses
    }
}

final class StubProcessController: @unchecked Sendable, ProcessControlling {
    var terminateRequests: [Int32] = []
    var killRequests: [Int32] = []

    func terminate(pid: Int32) async throws {
        terminateRequests.append(pid)
    }

    func kill(pid: Int32) async throws {
        killRequests.append(pid)
    }
}

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
