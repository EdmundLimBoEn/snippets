# Snippets smoke test

Run from a logged-in macOS desktop:

```sh
./scripts/e2e.sh
```

Quit any existing Snippets instance first. Keep TextEdit focused during the test and do not type or copy while it runs. Requirements: Xcode, XcodeGen, and the project's signing identity. The script polls up to 20 minutes for `Snippets/Store.swift` and `project.yml` if they are still being created.

The script builds all helpers with `swiftc`, generates the fixture with `swift`, and runs XcodeGen against a temporary source copy. The Debug build goes to `build/e2e`. This avoids XcodeGen rewriting the app's source Info.plist during concurrent development.

The fixture matches the array decoded by `Store.swift`. KeyboardShortcuts' synthesized Codable uses `carbonKeyCode` and `carbonModifiers`; Carbon Hyper is 6912, with virtual keycodes 29 (0) and 25 (9). The fixture uses Cocoa RTFD serialization and checks each RTFD round trip. The picker choice uses virtual keycode 19 (2).

Assertions:

- Hyper+0 inserts exactly `E2E-ALPHA` in the new TextEdit document.
- The clipboard returns to `SENTINEL` after one second.
- Hyper+9 followed by 2 produces exactly `E2E-ALPHAE2E-CHARLIE`.
- The clipboard again returns to `SENTINEL` after one second.

The trap stops only the process launched by the harness, closes only its TextEdit document without saving, restores the original clipboard representations, and restores the original snippets file. A timestamped `snippets.json.e2e-backup-*` copy remains for recovery. If there was no original file, test data is moved to `snippets.json.e2e-result-*` and the original absent-file state is restored. A lock prevents overlapping runs. SIGKILL/power loss cannot run a shell trap: recover from the retained backup and remove `.e2e-lock` only after confirming no run remains active.

Exit codes: 0 PASS, 1 FAIL, 77 BLOCKED. Runner Accessibility/event-posting permissions are checked before any live data is replaced. A copied ALPHA without a paste is reported as consistent with the app's Accessibility-denied fallback; other failed insertions remain failures because permissions, focus, and hotkey bugs cannot be distinguished conclusively from external observations.

Permissions, if blocked:

- **System Settings > Privacy & Security > Accessibility**: enable the launching terminal/host (Terminal, iTerm, or T3 Code), the `keys` helper if listed, and the built Snippets app at `build/e2e/Build/Products/Debug/Snippets.app`. Restart the affected process and rerun.
- Direct pane: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`.
- **System Settings > Privacy & Security > Automation**: allow the terminal/host to control TextEdit if macOS asks.

## First run in this workspace

Ran `bash -n scripts/e2e.sh`, then `scripts/e2e.sh` on 2026-10-13. Output summary:

```text
PASS: all three standalone Swift helpers compiled
PASS: fixture JSON and three RTFD round trips (Hyper+0 / Hyper+9)
PASS: XcodeGen project generation in isolated source copy
** BUILD SUCCEEDED **
PASS: Debug app build
PASS: runner Accessibility and event-posting preflight
BLOCKED: quit the existing Snippets app, then rerun; no live data was replaced
BLOCKED: E2E smoke test incomplete
```

Exit status was 77. The run did not reach app launch, TextEdit, paste assertions, or clipboard assertions. No missing runner Accessibility permission was detected; Snippets' own permission remains unverified. The lock was removed on exit.

Written by gpt-6-astra in Codex on behalf of Edmund
