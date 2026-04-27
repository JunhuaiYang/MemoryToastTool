import AppKit
import Foundation

final class AppLifecycleController: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func mainWindowDidOpen() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func mainWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }
}
