import AppKit
import Carbon.HIToolbox

// KeyboardShortcuts.Shortcut uses synthesized Codable for these two stored Ints.
struct Shortcut: Codable {
    let carbonKeyCode: Int
    let carbonModifiers: Int
}
struct Snippet: Codable {
    let id: UUID
    let name: String
    let rtfd: Data
}
struct Key: Codable {
    let id: UUID
    let name: String
    let shortcut: Shortcut
    let snippets: [Snippet]
}
func snippet(_ text: String) throws -> Snippet {
    let value = NSAttributedString(string: text)
    let data = try value.data(from: NSRange(location: 0, length: value.length),
                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    let decoded = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil)
    guard decoded.string == text else { throw NSError(domain: "RTFD round trip", code: 1) }
    return Snippet(id: UUID(), name: text, rtfd: data)
}
do {
    guard CommandLine.arguments.count == 2 else {
        throw NSError(domain: "Usage: make_fixture <output.json>", code: 2)
    }
    let hyper = Int(cmdKey | controlKey | optionKey | shiftKey)
    let keys = [
        Key(id: UUID(uuidString: "E2E00000-0000-4000-8000-000000000001")!, name: "E2E One",
            shortcut: Shortcut(carbonKeyCode: kVK_ANSI_0, carbonModifiers: hyper),
            snippets: [try snippet("E2E-ALPHA")]),
        Key(id: UUID(uuidString: "E2E00000-0000-4000-8000-000000000002")!, name: "E2E Two",
            shortcut: Shortcut(carbonKeyCode: kVK_ANSI_9, carbonModifiers: hyper),
            snippets: [try snippet("E2E-BRAVO"), try snippet("E2E-CHARLIE")])
    ]
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(keys).write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
    print("PASS: fixture JSON and three RTFD round trips (Hyper+0 / Hyper+9)")
} catch {
    fputs("FAIL: fixture: \(error)\n", stderr)
    exit(1)
}
