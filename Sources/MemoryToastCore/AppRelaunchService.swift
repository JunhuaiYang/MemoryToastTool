import AppKit
import Foundation

public protocol ApplicationWorkspace: Sendable {
    func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL?
    func openApplication(at url: URL)
}

public struct LiveApplicationWorkspace: ApplicationWorkspace {
    public init() {}

    public func applicationURL(forBundleIdentifier bundleIdentifier: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    public func openApplication(at url: URL) {
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}

public struct AppRelaunchService: Sendable {
    public let workspace: ApplicationWorkspace

    public init(workspace: ApplicationWorkspace = LiveApplicationWorkspace()) {
        self.workspace = workspace
    }

    public func relaunch(bundleIdentifier: String) {
        guard let appURL = workspace.applicationURL(forBundleIdentifier: bundleIdentifier) else {
            return
        }

        workspace.openApplication(at: appURL)
    }
}
