import AppKit
import SwiftUI

struct RichEditor: NSViewRepresentable {
    @Binding var rtfd: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(rtfd: $rtfd)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let textView = NSTextView()
        textView.isRichText = true
        textView.importsGraphics = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.delegate = context.coordinator
        scroll.documentView = textView
        updateNSView(scroll, context: context)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.rtfd = $rtfd
        guard context.coordinator.lastData != rtfd,
              let textView = scroll.documentView as? NSTextView else { return }
        context.coordinator.isLoading = true
        let content = NSAttributedString(rtfd: rtfd, documentAttributes: nil)
            ?? NSAttributedString(string: "")
        textView.textStorage?.setAttributedString(content)
        context.coordinator.lastData = rtfd
        context.coordinator.isLoading = false
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var rtfd: Binding<Data>
        var lastData: Data?
        var isLoading = false

        init(rtfd: Binding<Data>) {
            self.rtfd = rtfd
        }

        func textDidChange(_ notification: Notification) {
            guard !isLoading, let textView = notification.object as? NSTextView else { return }
            let content = textView.attributedString()
            guard let data = content.rtfd(
                from: NSRange(location: 0, length: content.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            ) else { return }
            lastData = data
            rtfd.wrappedValue = data
        }
    }
}
