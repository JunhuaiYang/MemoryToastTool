import SwiftUI

@main
struct MemoryToastToolApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleController.self) private var appLifecycleController

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
        Window("Settings", id: "main-window") {
            SettingsView(
                settings: $settings,
                onSave: saveSettings,
                onOpenAlert: presentCurrentAlertPanel
            )
            .onAppear {
                appLifecycleController.mainWindowDidOpen()
            }
            .onDisappear {
                appLifecycleController.mainWindowDidClose()
            }
        }
        .defaultSize(width: 460, height: 540)
        .windowResizability(.contentSize)

        MenuBarExtra(localizedString("menu.title", language: settings.languageOverride), systemImage: "memorychip") {
            MenuBarContainerView(
                viewModel: menuBarViewModel,
                alertSessionController: alertSessionController,
                settings: $settings,
                isIgnoringCurrentIncident: $isIgnoringCurrentIncident,
                onSaveSettings: saveSettings
            )
        }
        WindowGroup(id: "memory-alert") {
            AlertPanelView(
                controller: alertSessionController,
                settings: $settings,
                isIgnoringCurrentIncident: $isIgnoringCurrentIncident,
                onSaveSettings: saveSettings
            )
        }
        .defaultSize(width: 520, height: 360)
        .windowResizability(.contentSize)

        WindowGroup(id: "welcome-guide") {
            WelcomeGuideView(
                settings: $settings,
                onSave: saveSettings
            )
        }
        .defaultSize(width: 560, height: 340)
        .windowResizability(.contentSize)
    }

    private func saveSettings() {
        settingsStore.save(settings)
        menuBarViewModel.apply(settings: settings)
        alertSessionController.apply(settings: settings)
    }

    private func presentCurrentAlertPanel() async {
        guard let (snapshot, _, reasons) = await menuBarViewModel.refreshAndBuildAlertPayload() else {
            return
        }

        let selectedPIDs = DefaultSelectionPlanner().selectDefaultPIDs(
            from: snapshot.processes,
            count: settings.defaultSelectedAppCount,
            ignoredBundleIdentifiers: settings.ignoredBundleIdentifiers
        )

        alertSessionController.present(
            snapshot: snapshot,
            matchedReasons: reasons,
            selectedPIDs: selectedPIDs
        )
    }
}
