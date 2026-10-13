import AppKit
import ApplicationServices

@MainActor enum Paster {
    typealias Snapshot = [[NSPasteboard.PasteboardType: Data]]
    private static var pending: [Snippet] = []
    private static var isPasting = false

    static func snapshot(_ pasteboard: NSPasteboard) -> Snapshot {
        (pasteboard.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    static func restore(_ snapshot: Snapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let items = snapshot.map { representations in
            let item = NSPasteboardItem()
            for (type, data) in representations { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }

    static func copy(_ snippet: Snippet) {
        write(snippet, to: .general)
    }

    static func write(_ snippet: Snippet, to pasteboard: NSPasteboard) {
        let item = NSPasteboardItem()
        item.setData(snippet.rtfd, forType: .rtfd)
        let content = snippet.attributed
        if let rtf = try? content.data(from: NSRange(location: 0, length: content.length),
                                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            item.setData(rtf, forType: .rtf)
        }
        item.setString(snippet.plainText, forType: .string)
        if let image = snippet.image, let tiff = image.tiffRepresentation {
            item.setData(tiff, forType: .tiff)
            if let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                item.setData(png, forType: .png)
            }
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    static func paste(_ snippet: Snippet) {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            copy(snippet)
            return
        }
        pending.append(snippet)
        guard !isPasting else { return }
        isPasting = true
        Task { @MainActor in
            while !pending.isEmpty {
                let next = pending.removeFirst()
                for _ in 0..<25 {
                    if NSEvent.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty { break }
                    try? await Task.sleep(for: .milliseconds(20))
                }
                let source = CGEventSource(stateID: .combinedSessionState)
                guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                      let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else { continue }
                let previous = snapshot(.general)
                copy(next)
                let writtenChangeCount = NSPasteboard.general.changeCount
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
                // ponytail: fixed 500ms restore delay; target apps read the pasteboard async — raise if a slow app pastes the old clipboard.
                try? await Task.sleep(for: .milliseconds(500))
                // Preserve a newer copy made by the user or another app during the delay.
                if NSPasteboard.general.changeCount == writtenChangeCount {
                    restore(previous, to: .general)
                }
            }
            isPasting = false
        }
    }
}
