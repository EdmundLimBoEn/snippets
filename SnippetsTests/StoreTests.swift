import AppKit
import KeyboardShortcuts
import XCTest
@testable import Snippets

final class StoreTests: XCTestCase {
    @MainActor func testRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("snippets.json")
        let store = Store(fileURL: url)
        XCTAssertTrue(store.keys.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let rich = NSAttributedString(string: "Rich snippet", attributes: [.font: NSFont.boldSystemFont(ofSize: 18), .foregroundColor: NSColor.red])
        var snippet = Snippet(name: "Rich", text: "")
        snippet.rtfd = try rich.data(from: NSRange(location: 0, length: rich.length),
                                    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        let key = Key(name: "Test", shortcut: .init(.a, modifiers: [.command, .control, .option, .shift]), snippets: [snippet])
        store.keys.append(key)
        XCTAssertNil(store.persistenceError)
        let loaded = Store(fileURL: url)
        XCTAssertEqual(loaded.keys, [key])
        XCTAssertEqual(loaded.keys[0].snippets[0].plainText, "Rich snippet")
        let font = try XCTUnwrap(loaded.keys[0].snippets[0].attributed.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertTrue(NSFontManager.shared.traits(of: font).contains(.boldFontMask))
        store.keys[0].snippets[0].name = "Renamed"
        XCTAssertEqual(Store(fileURL: url).keys[0].snippets[0].name, "Renamed")
    }

    @MainActor func testCorruptFilePreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("snippets.json")
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: url)
        let store = Store(fileURL: url)
        XCTAssertTrue(store.keys.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let backup = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("snippets.corrupt-") })
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        store.keys = [Key(name: "New", snippets: [Snippet(name: "Plain", text: "hello")])]
        XCTAssertEqual(try Data(contentsOf: backup), corrupt)
        XCTAssertEqual(Store(fileURL: url).keys, store.keys)
    }

    @MainActor func testImageRepresentations() throws {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let wrapper = FileWrapper(regularFileWithContents: png)
        wrapper.preferredFilename = "image.png"
        let content = NSAttributedString(attachment: NSTextAttachment(fileWrapper: wrapper))
        var snippet = Snippet(name: "Image", text: "")
        snippet.rtfd = try content.data(from: NSRange(location: 0, length: content.length),
                                       documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        XCTAssertNotNil(snippet.image)
        let board = NSPasteboard(name: .init(UUID().uuidString))
        defer { board.releaseGlobally() }
        Paster.write(snippet, to: board)
        XCTAssertNotNil(board.data(forType: .tiff))
        XCTAssertNotNil(board.data(forType: .png))
        let mixed = NSMutableAttributedString(attributedString: content)
        mixed.append(NSAttributedString(string: " caption"))
        snippet.rtfd = try mixed.data(from: NSRange(location: 0, length: mixed.length),
                                     documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        XCTAssertNil(snippet.image)
    }

    @MainActor func testPasteboardRoundTrip() throws {
        let board = NSPasteboard(name: .init(UUID().uuidString))
        defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("sentinel", forType: .string)
        first.setData(Data([0, 1, 255]), forType: .init("com.example.custom"))
        let second = NSPasteboardItem()
        second.setString("second", forType: .string)
        board.writeObjects([first, second])
        let snapshot = try XCTUnwrap(Paster.snapshot(board))
        XCTAssertEqual(snapshot.count, 2)
        Paster.write(Snippet(name: "Replacement", text: "new"), to: board)
        XCTAssertEqual(board.string(forType: .string), "new")
        XCTAssertNotNil(board.data(forType: .rtfd))
        XCTAssertNotNil(board.data(forType: .rtf))
        Paster.restore(snapshot, to: board)
        XCTAssertEqual(Paster.snapshot(board), snapshot)
        Paster.restore([], to: board)
        XCTAssertEqual(Paster.snapshot(board), [])
    }
}
