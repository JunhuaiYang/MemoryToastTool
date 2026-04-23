import SwiftUI

@main
struct MemoryToastToolApp: App {
    private let settingsStore = SettingsStore()

    var body: some Scene {
        MenuBarExtra("Memory Toast Tool", systemImage: "memorychip") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Memory Toast Tool")
                    .font(.headline)
                Text("Bootstrapping...")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        Settings {
            Text("Settings view is not wired yet.")
                .padding(20)
        }
    }
}
