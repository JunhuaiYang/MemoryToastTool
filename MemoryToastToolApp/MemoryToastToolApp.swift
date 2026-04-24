import SwiftUI

@main
struct MemoryToastToolApp: App {
    private let settingsStore: SettingsStore
    @State private var settings: AppSettings
    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var alertSessionController: AlertSessionController

    init() {
        let store = SettingsStore()
        let loadedSettings = store.load()
        let menuBarViewModel = MenuBarViewModel()
        menuBarViewModel.apply(settings: loadedSettings)

        self.settingsStore = store
        _settings = State(initialValue: loadedSettings)
        _menuBarViewModel = StateObject(wrappedValue: menuBarViewModel)
        _alertSessionController = StateObject(
            wrappedValue: AlertSessionController(
                countdownSeconds: loadedSettings.forceQuitRevealDelaySeconds,
                appActionService: AppActionService(),
                relaunchService: AppRelaunchService()
            )
        )
    }

    var body: some Scene {
        MenuBarExtra("Memory Toast Tool", systemImage: "memorychip") {
            MenuBarContainerView(
                viewModel: menuBarViewModel,
                alertSessionController: alertSessionController,
                settings: $settings
            )
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
        WindowGroup(id: "memory-alert") {
            AlertPanelView(controller: alertSessionController)
        }
        .defaultSize(width: 520, height: 360)
        .windowResizability(.contentSize)
    }
}
