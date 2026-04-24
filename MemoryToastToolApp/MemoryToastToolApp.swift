import SwiftUI

@main
struct MemoryToastToolApp: App {
    private let settingsStore = SettingsStore()
    @State private var settings = AppSettings.defaultValue
    @StateObject private var menuBarViewModel = MenuBarViewModel()
    @StateObject private var alertSessionController = AlertSessionController(
        countdownSeconds: 10,
        appActionService: AppActionService(),
        relaunchService: AppRelaunchService()
    )

    var body: some Scene {
        MenuBarExtra("Memory Toast Tool", systemImage: "memorychip") {
            MenuBarView(
                viewModel: menuBarViewModel,
                settings: settings,
                onRefresh: {
                    Task { await menuBarViewModel.refresh() }
                },
                onOpenAlert: {}
            )
            .task {
                if settings == .defaultValue {
                    settings = settingsStore.load()
                    menuBarViewModel.apply(settings: settings)
                }
                await menuBarViewModel.refresh()
            }
        }
        Settings {
            SettingsView(
                settings: $settings,
                onSave: {
                    settingsStore.save(settings)
                    menuBarViewModel.apply(settings: settings)
                }
            )
        }
        Window("Memory Alert", id: "memory-alert") {
            AlertPanelView(controller: alertSessionController)
        }
        .defaultSize(width: 520, height: 360)
    }
}
