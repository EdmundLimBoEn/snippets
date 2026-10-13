import AppKit
import SwiftUI

@MainActor final class PickerPanel: NSPanel, NSWindowDelegate {
    private static var current: PickerPanel?
    private let selection: PickerSelection
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static func show(_ key: Key) {
        dismiss()
        let panel = PickerPanel(key: key)
        current = panel
        panel.makeKeyAndOrderFront(nil)
    }

    static func dismiss() {
        current?.orderOut(nil)
        current = nil
    }

    private init(key: Key) {
        selection = PickerSelection(key: key)
        super.init(contentRect: NSRect(x: 0, y: 0, width: 500, height: min(440, 56 + key.snippets.count * 48)),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        delegate = self
        contentView = NSHostingView(rootView: PickerView(selection: selection) { [weak self] index in
            self?.choose(index)
        })
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            setFrameOrigin(NSPoint(x: frame.midX - self.frame.width / 2, y: frame.midY - self.frame.height / 2))
        }
    }

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .keyDown else {
            super.sendEvent(event)
            return
        }
        switch event.keyCode {
        case 53: Self.dismiss()
        case 126: selection.index = max(0, selection.index - 1)
        case 125: selection.index = min(selection.key.snippets.count - 1, selection.index + 1)
        case 36, 76: choose(selection.index)
        default:
            if let index = [18, 19, 20, 21, 23, 22, 26, 28, 25].firstIndex(of: Int(event.keyCode)) {
                choose(index)
            } else {
                super.sendEvent(event)
            }
        }
    }

    private func choose(_ index: Int) {
        guard selection.key.snippets.indices.contains(index) else { return }
        let snippet = selection.key.snippets[index]
        Self.dismiss()
        Paster.paste(snippet)
    }

    func windowDidResignKey(_ notification: Notification) {
        if Self.current === self { Self.dismiss() }
    }
}

@Observable @MainActor private final class PickerSelection {
    let key: Key
    var index = 0
    init(key: Key) { self.key = key }
}

private struct PickerView: View {
    let selection: PickerSelection
    let choose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selection.key.name).font(.headline).padding(.horizontal, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(selection.key.snippets.enumerated()), id: \.element.id) { index, snippet in
                            Button { choose(index) } label: {
                                HStack(spacing: 12) {
                                    Text(index < 9 ? "\(index + 1)" : " ")
                                        .monospacedDigit().foregroundStyle(.secondary).frame(width: 18)
                                    Text(snippet.name).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(snippet.plainText.replacingOccurrences(of: "\n", with: " "))
                                        .foregroundStyle(.tertiary).lineLimit(1).frame(maxWidth: 260, alignment: .trailing)
                                }
                                .padding(10)
                                .contentShape(Rectangle())
                                .background(selection.index == index ? Color.accentColor.opacity(0.18) : .clear,
                                            in: RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                }
                .onChange(of: selection.index) { _, index in proxy.scrollTo(index) }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
