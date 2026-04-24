import AppKit
import Foundation

public protocol WorkspaceControlling: Sendable {
    func requestQuit(bundleIdentifier: String) async throws
    func forceQuit(bundleIdentifier: String) async throws
}

public struct LiveWorkspaceController: WorkspaceControlling {
    public init() {}

    public func requestQuit(bundleIdentifier: String) async throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return
        }

        _ = app.terminate()
    }

    public func forceQuit(bundleIdentifier: String) async throws {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            return
        }

        _ = app.forceTerminate()
    }
}

public struct AppActionService: Sendable {
    public let workspace: WorkspaceControlling

    public init(workspace: WorkspaceControlling = LiveWorkspaceController()) {
        self.workspace = workspace
    }

    public func requestQuit(bundleIdentifier: String) async throws {
        try await workspace.requestQuit(bundleIdentifier: bundleIdentifier)
    }

    public func forceQuit(bundleIdentifier: String) async throws {
        try await workspace.forceQuit(bundleIdentifier: bundleIdentifier)
    }
}
