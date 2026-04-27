import AppKit
import Foundation

@MainActor
final class AppLifecycleController: NSObject, NSApplicationDelegate {
    private let singleInstancePolicy = SingleInstancePolicy()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if enforceSingleInstance() {
            return
        }

        NSApp.setActivationPolicy(.accessory)
    }

    func mainWindowDidOpen() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func mainWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }

    private func enforceSingleInstance() -> Bool {
        let currentProcessIdentifier = Int32(ProcessInfo.processInfo.processIdentifier)
        let bundleIdentifier = Bundle.main.bundleIdentifier
        let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier ?? "")
        let decision = singleInstancePolicy.decision(
            bundleIdentifier: bundleIdentifier,
            currentProcessIdentifier: currentProcessIdentifier,
            runningProcessIdentifiers: runningApplications.map { Int32($0.processIdentifier) }
        )

        guard case .activateExistingAndTerminateCurrent(let existingProcessIdentifier) = decision else {
            return false
        }

        runningApplications
            .first(where: { Int32($0.processIdentifier) == existingProcessIdentifier })?
            .activate(options: [.activateAllWindows])

        NSApp.terminate(nil)
        return true
    }
}
