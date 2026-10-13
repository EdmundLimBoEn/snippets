import AppKit
import KeyboardShortcuts
import Observation

struct Key: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var shortcut: KeyboardShortcuts.Shortcut?
    var snippets: [Snippet]
}

struct Snippet: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    // ponytail: images inline as base64 in one JSON; split to a files dir if it bloats.
    var rtfd: Data

    init(name: String, text: String) {
        self.name = name
        let attributed = NSAttributedString(string: text)
        rtfd = (try? attributed.data(from: NSRange(location: 0, length: attributed.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])) ?? Data()
    }

    var attributed: NSAttributedString {
        (try? NSAttributedString(data: rtfd, options: [.documentType: NSAttributedString.DocumentType.rtfd],
                                documentAttributes: nil)) ?? NSAttributedString(string: "")
    }

    var plainText: String { attributed.string }

    var image: NSImage? {
        let content = attributed
        guard content.length == 1,
              let attachment = content.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment else { return nil }
        if let image = attachment.image { return image }
        if let data = attachment.fileWrapper?.regularFileContents { return NSImage(data: data) }
        return (attachment.attachmentCell as? NSTextAttachmentCell)?.image
    }
}

@Observable @MainActor final class Store {
    var keys: [Key] = [] {
        didSet {
            save()
            onChange?()
        }
    }
    private(set) var persistenceError: String?
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var canSave = true

    init(fileURL: URL = URL.applicationSupportDirectory.appending(path: "Snippets/snippets.json")) {
        self.fileURL = fileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            canSave = false
            persistenceError = error.localizedDescription
            return
        }
        do {
            keys = try JSONDecoder().decode([Key].self, from: data)
        } catch {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("snippets.corrupt-\(timestamp)-\(UUID().uuidString).json")
            do {
                try FileManager.default.moveItem(at: fileURL, to: backup)
            } catch {
                // Never overwrite unreadable data when preserving the original fails.
                canSave = false
                persistenceError = error.localizedDescription
            }
        }
    }

    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(keys).write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
