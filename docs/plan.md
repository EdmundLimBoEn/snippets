# Snippets — macOS menu bar app (build-day MVP)

## Context
Edmund retypes/hunts for the same info (emails, LinkedIn/socials, key websites). Snippets is a native Swift menu bar app: Hyper (caps lock, already mapped to ⌃⌥⇧⌘ by Karabiner) + any key pastes a saved snippet into the focused field, or pops a numbered picker when that key holds several. Personal use only, local-only storage, sync-ready later. Repo `EdmundLimBoEn/snippets` (private) is empty apart from README.

## Locked decisions (from grilling)
- **Model:** a *Key* = name + optional shortcut + 1..n snippets. 1 snippet → direct paste. 2+ → picker. No shortcut → menu bar only.
- **Paste:** snapshot clipboard → write snippet → synthetic ⌘V → restore clipboard. Clipboard ends exactly as before.
- **Picker:** centred floating panel, items numbered 1–9; press number, or ↑↓ + Enter; Esc cancels.
- **Content:** plain text, rich text, images — one rich editor (NSTextView, `isRichText`, `importsGraphics`) stored as RTFD. Typing, pasting, or dragging an image all just work.
- **Menu bar:** icon only (LSUIElement, no Dock). Menu lists every key's snippets; click = copy to clipboard. Plus "Settings…" and "Quit". Launch at login.
- **Settings (Wispr Flow style):** left sidebar lists keys (name + shortcut glyph), "+ New Key", "General" pinned bottom. Right pane: serif title + rounded beige cards, rows with right-aligned "Change"/"Edit" buttons. General: launch-at-login toggle, Accessibility status + "Open System Settings".
- **First run:** completely empty.
- **Not doing:** Hyper conflict warnings, sensitive-data handling, clipboard history, sync, notarization.

## Architecture (single app target, ~8 files)
```
project.yml                     xcodegen spec; macOS 26 target; LSUIElement; signed "Apple Development"; SPM dep KeyboardShortcuts
Snippets/SnippetsApp.swift      @main; MenuBarExtra(.menu) + Settings window scene
Snippets/Store.swift            @Observable; [Key]; load/save JSON at ~/Library/Application Support/Snippets/snippets.json
Snippets/Hotkeys.swift          per-Key KeyboardShortcuts.Name(key.id); onKeyUp → Paster or Picker; re-registers on store change
Snippets/Paster.swift           pasteboard snapshot/restore + CGEvent ⌘V; Accessibility check/prompt
Snippets/PickerPanel.swift      nonactivating NSPanel hosting SwiftUI list; keyboard handling
Snippets/SettingsView.swift     sidebar + key detail cards + General pane
Snippets/RichEditor.swift       NSViewRepresentable NSTextView ↔ RTFD Data
SnippetsTests/StoreTests.swift  JSON round-trip incl. RTFD + shortcut
```
- **Data:** `struct Key: Codable, Identifiable { id: UUID; name; shortcut: KeyboardShortcuts.Shortcut?; snippets: [Snippet] }`, `struct Snippet { id; name; rtfd: Data }`. Shortcut lives in the JSON (single source of truth → sync later = move the file); on load, push into KeyboardShortcuts via `setShortcut`. `// ponytail: images inline as base64 in one JSON; split to a files dir if it bloats.`
- **Hotkeys:** KeyboardShortcuts (sindresorhus) = Carbon `RegisterEventHotKey` (no permission needed) + a ready `Recorder` view for the "Change" button. Justified dependency: replaces ~150 lines of Carbon + recorder code.
- **Paster:** save all `NSPasteboard.general.pasteboardItems` (every type's data) → clear → write RTFD, RTF, plain string, and TIFF if the snippet is a single image → post ⌘V via `CGEvent` (`.cghidEventTap`) → restore after delay. `// ponytail: fixed 300ms restore delay; target apps read the pasteboard async — tune if a slow app pastes the old clipboard.` If `AXIsProcessTrusted()` is false: prompt via `AXIsProcessTrustedWithOptions` and fall back to copy-only.
- **Picker focus:** `NSPanel` with `.nonactivatingPanel` + `canBecomeKey = true` so it takes keystrokes without activating Snippets; the previous app stays frontmost, so ⌘V lands in the original field after the panel closes. **Key risk — verify first.**
- **Launch at login:** `SMAppService.mainApp.register()/unregister()` behind the General toggle.

## Execution — Claude orchestrates, Codex builds
Work on branch `feat/mvp` in this repo; Codex via `codex:codex-rescue` (GPT-5.6-terra), small sequential waves (files overlap, so no parallel writers).
1. **Wave 1 — core loop (Codex):** project.yml, App shell + MenuBarExtra, Store, Hotkeys, Paster, PickerPanel, StoreTests. Acceptance: `xcodegen && xcodebuild build test` passes; a hard-coded test key pastes into TextEdit and restores clipboard.
2. **Wave 2 — Settings + menu (Codex):** SettingsView (Wispr layout above), RichEditor, General pane, menu bar copy items. Acceptance: create/rename/delete keys and snippets, record shortcut, persists across relaunch.
3. **Review (Codex GPT-5.6-sol, one pass):** correctness of pasteboard restore, panel focus, hotkey re-registration on edit/delete.
4. **Me:** read diffs between waves, run builds, fix integration, open PR → merge, then build Release, copy to `/Applications/Snippets.app`, enable login item.

## Verification
- `xcodegen generate && xcodebuild -scheme Snippets -destination 'platform=macOS' build test | tail`
- Manual on Edmund's Mac (needs real Hyper key + Accessibility grant):
  1. Settings → New Key "Emails", shortcut caps+Q, 3 snippets; New Key "Site", caps+Z, 1 snippet with a link; one snippet with bold text, one with an image.
  2. Copy "SENTINEL" to clipboard. In TextEdit/Notes/Chrome field: caps+Z pastes directly; caps+Q shows picker, `2` pastes item 2; ⌘V afterwards still gives "SENTINEL".
  3. Rich text keeps formatting in Notes, arrives plain in a browser input; image pastes into Notes/Messages.
  4. Menu bar click copies a snippet. Quit + relaunch: everything persists. Reboot/log out: app starts at login.

## Human actions (will also go in HUMANS.md)
- Grant Accessibility to Snippets on first paste (System Settings → Privacy & Security → Accessibility).
- Run the manual checks above with your real caps-lock Hyper key.
