import SwiftUI

@main
struct SnippetsApp: App {
    @State private var store: Store
    private let hotkeys: Hotkeys

    init() {
        let store = Store()
        _store = State(initialValue: store)
        hotkeys = Hotkeys(store: store)
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
            Button("Quit") { NSApplication.shared.terminate(nil) }
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
