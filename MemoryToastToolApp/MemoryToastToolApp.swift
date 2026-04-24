import SwiftUI

@main
struct MemoryToastToolApp: App {
    private let settingsStore: SettingsStore
    @State private var settings: AppSettings
    @State private var isIgnoringCurrentIncident = false
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
                relaunchDelaySeconds: loadedSettings.relaunchDelaySeconds,
                appActionService: AppActionService(),
                relaunchService: AppRelaunchService()
            )
        )
    }

    var body: some Scene {
        MenuBarExtra(localizedString("menu.title", language: settings.languageOverride), systemImage: "memorychip") {
            MenuBarContainerView(
                viewModel: menuBarViewModel,
                alertSessionController: alertSessionController,
                settings: $settings,
                isIgnoringCurrentIncident: $isIgnoringCurrentIncident,
                onSaveSettings: {
                    settingsStore.save(settings)
                    menuBarViewModel.apply(settings: settings)
                    alertSessionController.apply(settings: settings)
                }
            )
        }
        Settings {
            SettingsView(
                settings: $settings,
                onSave: {
                    settingsStore.save(settings)
                    menuBarViewModel.apply(settings: settings)
                    alertSessionController.apply(settings: settings)
                }
            )
        }
        WindowGroup(id: "memory-alert") {
            AlertPanelView(
                controller: alertSessionController,
                settings: $settings,
                isIgnoringCurrentIncident: $isIgnoringCurrentIncident,
                onSaveSettings: {
                    settingsStore.save(settings)
                    menuBarViewModel.apply(settings: settings)
                    alertSessionController.apply(settings: settings)
                }
            )
        }
        .defaultSize(width: 520, height: 360)
        .windowResizability(.contentSize)

        WindowGroup(id: "welcome-guide") {
            WelcomeGuideView(
                settings: $settings,
                onSave: {
                    settingsStore.save(settings)
                    menuBarViewModel.apply(settings: settings)
                    alertSessionController.apply(settings: settings)
                }
            )
        }
        .defaultSize(width: 560, height: 340)
        .windowResizability(.contentSize)
    }
}
