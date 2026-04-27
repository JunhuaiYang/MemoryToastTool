import AppKit
import Darwin
import Foundation

public protocol WorkspaceControlling: Sendable {
    func requestQuit(bundleIdentifier: String) async throws
    func forceQuit(bundleIdentifier: String) async throws
}

public protocol ProcessControlling: Sendable {
    func terminate(pid: Int32) async throws
    func kill(pid: Int32) async throws
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

    public func requestQuit(bundleIdentifier: String) async throws {
        try await workspace.requestQuit(bundleIdentifier: bundleIdentifier)
    }

    public func forceQuit(bundleIdentifier: String) async throws {
        try await workspace.forceQuit(bundleIdentifier: bundleIdentifier)
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
