import AppKit
import ApplicationServices
import KeyboardShortcuts

@MainActor final class Hotkeys {
    private let store: Store
    private var registered: Set<KeyboardShortcuts.Name> = []
    private var focusCheck: Task<Void, Never>?

    init(store: Store) {
        self.store = store
        store.onChange = { [weak self] in self?.sync() }
        sync()
    }

    private func sync() {
        focusCheck?.cancel()
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
                guard let self, let key = self.store.keys.first(where: { $0.id == key.id }),
                      let snippet = key.snippets.first else { return }
                self.focusCheck?.cancel()
                guard AXIsProcessTrusted() else {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                    if key.snippets.count == 1 { Paster.copy(snippet) }
                    return
                }
                guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return }
                self.focusCheck = Task {
                    let hasInput = await Paster.hasFocusedTextInput(in: pid)
                    guard !Task.isCancelled,
                          NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
                    guard hasInput else {
                        PickerPanel.dismiss()
                        NoInputPanel.show()
                        return
                    }
                    NoInputPanel.dismiss()
                    if key.snippets.count == 1 {
                        Paster.paste(snippet)
                    } else {
                        PickerPanel.show(key)
                    }
                }
            }
        }
    }
}
