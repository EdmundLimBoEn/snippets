import KeyboardShortcuts

@MainActor final class Hotkeys {
    private let store: Store
    private var registered: Set<KeyboardShortcuts.Name> = []

    init(store: Store) {
        self.store = store
        store.onChange = { [weak self] in self?.sync() }
        sync()
    }

    private func sync() {
        PickerPanel.dismiss()
        for name in registered {
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.setShortcut(nil, for: name)
        }
        registered.removeAll()
        for key in store.keys {
            let name = KeyboardShortcuts.Name(key.id.uuidString)
            KeyboardShortcuts.setShortcut(key.shortcut, for: name)
            guard key.shortcut != nil else { continue }
            registered.insert(name)
            KeyboardShortcuts.onKeyUp(for: name) { [weak self] in
                guard let key = self?.store.keys.first(where: { $0.id == key.id }) else { return }
                if key.snippets.count == 1, let snippet = key.snippets.first {
                    Paster.paste(snippet)
                } else if key.snippets.count > 1 {
                    PickerPanel.show(key)
                }
            }
        }
    }
}
