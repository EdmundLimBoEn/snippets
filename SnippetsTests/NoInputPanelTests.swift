import AppKit
import XCTest
@testable import Snippets

final class NoInputPanelTests: XCTestCase {
    @MainActor func testPopupIsCenteredAndDismissesWithoutTakingInput() async throws {
        defer { NoInputPanel.dismiss() }
        let screen = try XCTUnwrap(NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main)
        NoInputPanel.show()
        let panel = try XCTUnwrap(NSApp.windows.first { $0 is NoInputPanel && $0.isVisible })

        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(panel.frame.midX, screen.frame.midX, accuracy: 1)
        XCTAssertEqual(panel.frame.midY, screen.frame.midY, accuracy: 1)

        try await Task.sleep(for: .milliseconds(650))
        XCTAssertFalse(panel.isVisible)
    }
}
