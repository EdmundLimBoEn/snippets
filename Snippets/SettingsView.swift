import AppKit
import ApplicationServices
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let store: Store
    @State private var selection: UUID?
    @State private var showsGeneral = false
    @State private var deletingKey: Key?
    @State private var editingSnippet: Snippet?
    @State private var editingKeyID: UUID?
    @Environment(\.colorScheme) private var colorScheme

    private var cardColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.055) : Color(red: 0.96, green: 0.945, blue: 0.915)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            Group {
                if showsGeneral {
                    GeneralSettingsView(cardColor: cardColor)
                } else if let key = store.keys.first(where: { $0.id == selection }) {
                    keyDetail(key)
                } else {
                    VStack(spacing: 14) {
                        Text("Your words, a shortcut away.")
                            .font(.system(.title2, design: .serif))
                        Text("Create a key to keep your first snippet handy.")
                            .foregroundStyle(.secondary)
                        Button("New Key", action: addKey)
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 860, height: 560)
        .onAppear {
            if selection == nil { selection = store.keys.first?.id }
        }
        .alert("Delete key?", isPresented: Binding(
            get: { deletingKey != nil },
            set: { if !$0 { deletingKey = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingKey = nil }
            Button("Delete", role: .destructive) {
                guard let key = deletingKey else { return }
                store.keys.removeAll { $0.id == key.id }
                if selection == key.id { selection = store.keys.first?.id }
                deletingKey = nil
            }
        } message: {
            Text("“\(deletingKey?.name ?? "")” and its snippets will be deleted.")
        }
        .sheet(item: $editingSnippet) { snippet in
            SnippetEditorSheet(snippet: snippet) { updated in
                guard let index = store.keys.firstIndex(where: { $0.id == editingKeyID }) else { return }
                if let snippetIndex = store.keys[index].snippets.firstIndex(where: { $0.id == updated.id }) {
                    store.keys[index].snippets[snippetIndex] = updated
                } else {
                    store.keys[index].snippets.append(updated)
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEYS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 24)
            List(selection: $selection) {
                ForEach(store.keys) { key in
                    HStack(spacing: 8) {
                        Text(key.name).lineLimit(1)
                        Spacer(minLength: 0)
                        Text(key.shortcut?.description ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                    .tag(key.id)
                    .contextMenu {
                        Button("Delete Key…", role: .destructive) { deletingKey = key }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: selection) { _, value in
                if value != nil { showsGeneral = false }
            }
            .onDeleteCommand {
                if !showsGeneral { deletingKey = store.keys.first { $0.id == selection } }
            }
            Button(action: addKey) {
                Label("New Key", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(12)
            Divider()
            Button {
                selection = nil
                showsGeneral = true
            } label: {
                Label("General", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(showsGeneral ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func keyBinding(_ key: Key) -> Binding<Key> {
        Binding {
            store.keys.first { $0.id == key.id } ?? key
        } set: { updated in
            guard let index = store.keys.firstIndex(where: { $0.id == key.id }) else { return }
            store.keys[index] = updated
        }
    }

    private func keyDetail(_ key: Key) -> some View {
        let binding = keyBinding(key)
        return VStack(alignment: .leading, spacing: 20) {
            Text(key.name.isEmpty ? "Untitled Key" : key.name)
                .font(.system(.largeTitle, design: .serif))
                .lineLimit(1)
            VStack(spacing: 0) {
                HStack {
                    Text("Name").fontWeight(.semibold)
                    Spacer()
                    TextField("Key name", text: binding.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }
                .padding(16)
                Divider().padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Shortcut").fontWeight(.semibold)
                        Text("1 snippet pastes directly · 2+ shows a picker")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShortcutRecorder(shortcut: binding.shortcut)
                    .id(key.id)
                }
                .padding(16)
            }
            .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 0) {
                Text("Snippets").fontWeight(.semibold).padding(16)
                Divider().padding(.horizontal, 16)
                if key.snippets.isEmpty {
                    Text("Add text, rich text, or an image.")
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                } else {
                    List {
                        ForEach(Array(key.snippets.enumerated()), id: \.element.id) { number, snippet in
                            HStack(spacing: 12) {
                                Text("\(number + 1)")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(snippet.name).fontWeight(.medium).lineLimit(1)
                                    Text(snippet.image != nil ? "Image" : snippet.plainText.replacingOccurrences(of: "\n", with: " "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Button("Edit") { edit(snippet, in: key) }
                                    .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 5)
                            .listRowBackground(Color.clear)
                            .contextMenu {
                                Button("Delete Snippet", role: .destructive) {
                                    binding.snippets.wrappedValue.removeAll { $0.id == snippet.id }
                                }
                            }
                        }
                        .onMove { source, destination in
                            binding.snippets.wrappedValue.move(fromOffsets: source, toOffset: destination)
                        }
                        .onDelete { offsets in
                            binding.snippets.wrappedValue.remove(atOffsets: offsets)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                Divider().padding(.horizontal, 16)
                Button {
                    edit(Snippet(name: "", text: ""), in: key)
                } label: {
                    Label("Add snippet", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .padding(16)
            }
            .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func addKey() {
        let key = Key(name: "New Key", shortcut: nil, snippets: [])
        store.keys.append(key)
        selection = key.id
        showsGeneral = false
    }

    private func edit(_ snippet: Snippet, in key: Key) {
        editingKeyID = key.id
        editingSnippet = snippet
    }
}

private struct ShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcuts.Shortcut?
    @State private var monitor: Any?
    @State private var hotkeysWereEnabled = true
    @State private var capturedKeyCode: UInt16?
    @State private var capturedShortcut: KeyboardShortcuts.Shortcut?

    private var isRecording: Bool { monitor != nil }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: startRecording) {
                Text(isRecording ? "Press keys…" : shortcut?.description ?? "Record shortcut")
                    .font(.system(size: 13, weight: .medium))
                    .frame(minWidth: 120)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(isRecording ? 0.12 : 0.06), in: Capsule())
                    .overlay(Capsule().stroke(isRecording ? Color.accentColor : Color.primary.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRecording ? "Press keys…" : "Record shortcut")
            .accessibilityValue(shortcut?.description ?? "Not set")
            if shortcut != nil {
                Button {
                    stopRecording()
                    shortcut = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear shortcut")
            }
        }
        .onDisappear(perform: stopRecording)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            stopRecording()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        NSApp.activate()
        NSApp.keyWindow?.makeFirstResponder(nil)
        hotkeysWereEnabled = KeyboardShortcuts.isEnabled
        KeyboardShortcuts.isEnabled = false
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            if let capturedKeyCode {
                if event.type == .keyUp, event.keyCode == capturedKeyCode {
                    let recorded = capturedShortcut
                    stopRecording()
                    shortcut = recorded
                }
                return nil
            }
            guard event.type == .keyDown else { return nil }
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            guard !event.isARepeat,
                  !event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let recorded = KeyboardShortcuts.Shortcut(event: event) else { return nil }
            // Keep hotkeys suspended through key-up so recording cannot trigger a paste.
            capturedKeyCode = event.keyCode
            capturedShortcut = recorded
            return nil
        }
    }

    private func stopRecording() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        capturedKeyCode = nil
        capturedShortcut = nil
        KeyboardShortcuts.isEnabled = hotkeysWereEnabled
    }
}

private struct SnippetEditorSheet: View {
    @State var snippet: Snippet
    let save: (Snippet) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit snippet").font(.system(.title, design: .serif))
            TextField("Name", text: $snippet.name).textFieldStyle(.roundedBorder)
            RichEditor(rtfd: $snippet.rtfd)
                .frame(minHeight: 180)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator))
            Text("Paste or drag images here. Select text and press ⌘T to change its font.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") {
                    if snippet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let text = snippet.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "\n", with: " ")
                        snippet.name = String(text.prefix(30))
                        if snippet.name.isEmpty { snippet.name = snippet.image == nil ? "Untitled snippet" : "Image" }
                    }
                    save(snippet)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 540, height: 360)
    }
}

private struct GeneralSettingsView: View {
    let cardColor: Color
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var loginError: String?
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let fileURL = URL.homeDirectory.appending(path: "Library/Application Support/Snippets/snippets.json")

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General").font(.system(.largeTitle, design: .serif))
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Launch at login").fontWeight(.semibold)
                        Text("Keep your snippets ready when you sign in.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginError = SMAppService.mainApp.status == .requiresApproval
                                ? "Allow Snippets in System Settings → General → Login Items." : nil
                        } catch { loginError = error.localizedDescription }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }))
                    .labelsHidden()
                }
                .padding(16)
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding([.horizontal, .bottom], 16)
                }
                Divider().padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Accessibility").fontWeight(.semibold)
                        Text(accessibilityGranted ? "Granted" : "Not granted")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                Divider().padding(.horizontal, 16)
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Snippets file").fontWeight(.semibold)
                        Text("~/Library/Application Support/Snippets/snippets.json")
                            .font(.caption).foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button("Reveal") { NSWorkspace.shared.activateFileViewerSelecting([fileURL]) }
                        .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .background(cardColor, in: RoundedRectangle(cornerRadius: 12))
        }
        .onAppear(perform: refresh)
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        accessibilityGranted = AXIsProcessTrusted()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
