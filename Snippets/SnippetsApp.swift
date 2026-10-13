import SwiftUI
import Sparkle

@main
struct SnippetsApp: App {
    @State private var store: Store
    private let hotkeys: Hotkeys
    private let updaterController: SPUStandardUpdaterController

    init() {
        let store = Store()
        _store = State(initialValue: store)
        hotkeys = Hotkeys(store: store)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
    }

    var body: some Scene {
        MenuBarExtra("Snippets", image: "MenuBarIcon") {
            ForEach(store.keys) { key in
                Section(key.name) {
                    ForEach(key.snippets) { snippet in
                        Button(snippet.name) { Paster.copy(snippet) }
                    }
                }
            }
            if store.keys.isEmpty { Text("No snippets yet") }
            if let error = store.persistenceError { Text("Could not save or load snippets: \(error)") }
            Divider()
            OpenSettingsButton()
            CheckForUpdatesButton(updater: updaterController.updater)
            Button("Quit") {
                Paster.restoreIfUnchanged()
                NSApplication.shared.terminate(nil)
            }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
        Settings {
            SettingsView(store: store)
        }
    }
}

private struct OpenSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            // Accessory (LSUIElement) apps aren't active, so the window would open behind others.
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")
    }
}

private final class UpdateAvailability: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

private struct CheckForUpdatesButton: View {
    @StateObject private var availability: UpdateAvailability
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        _availability = StateObject(wrappedValue: UpdateAvailability(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!availability.canCheckForUpdates)
    }
}
