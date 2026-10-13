import AppKit

// Preserve every materialized representation, including images and rich text.
let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2, ["save", "restore"].contains(args[0]) else { exit(2) }
let url = URL(fileURLWithPath: args[1])
let board = NSPasteboard.general
do {
    if args[0] == "save" {
        let items = (board.pasteboardItems ?? []).map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type.rawValue, $0) }
            })
        }
        try PropertyListEncoder().encode(items).write(to: url, options: .atomic)
    } else {
        let saved = try PropertyListDecoder().decode([[String: Data]].self, from: Data(contentsOf: url))
        let items = saved.map { values in
            let item = NSPasteboardItem()
            for (type, data) in values { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
            return item
        }
        board.clearContents()
        if !items.isEmpty { board.writeObjects(items) }
    }
} catch {
    fputs("FAIL: clipboard \(args[0]): \(error)\n", stderr)
    exit(1)
}
