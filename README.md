<img src="assets/icon.svg" width="64" height="64" alt="">

# Snippets

Menu bar app for macOS. Press Hyper (caps lock via Karabiner, ⌃⌥⇧⌘) + any key to paste a saved snippet into the focused field. A key with several snippets shows a numbered picker. Your clipboard is restored afterwards.

- Plain text, rich text and images
- Click the menu bar icon to copy any snippet by hand
- Settings → keys on the left, snippets on the right
- Data lives locally in `~/Library/Application Support/Snippets/snippets.json`

## Build

```sh
xcodegen generate
xcodebuild -project Snippets.xcodeproj -scheme Snippets -destination 'platform=macOS' build test
```

Pasting needs Accessibility permission (prompted on first use).
