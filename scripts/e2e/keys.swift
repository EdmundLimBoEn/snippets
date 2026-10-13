import AppKit
import ApplicationServices

func blocked() -> Never {
    fputs("BLOCKED: synthetic keyboard events are not authorized for this runner.\nGrant the terminal/host (Terminal, iTerm, or T3 Code) and, if listed, the keys helper in System Settings > Privacy & Security > Accessibility. Restart the host and rerun.\nPane: x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility\n", stderr)
    exit(77)
}
let args = Array(CommandLine.arguments.dropFirst())
if args == ["--check"] {
    guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { blocked() }
    print("PASS: runner Accessibility and event-posting preflight")
    exit(0)
}
guard args.count == 2, ["hyper", "plain"].contains(args[0]),
      let code = UInt16(args[1]), code <= 127 else {
    fputs("Usage: keys --check | keys hyper|plain <virtual-keycode>\n", stderr)
    exit(2)
}
guard AXIsProcessTrusted(), CGPreflightPostEventAccess() else { blocked() }
let source = CGEventSource(stateID: .privateState)
let flags: CGEventFlags = args[0] == "hyper" ? [.maskControl, .maskAlternate, .maskShift, .maskCommand] : []
guard let down = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true),
      let up = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else {
    fputs("FAIL: cannot create CGEvent\n", stderr)
    exit(1)
}
down.flags = flags
up.flags = flags
down.post(tap: .cghidEventTap)
usleep(80_000)
up.post(tap: .cghidEventTap)
// Release modifier state after the hotkey's key-up callback has been delivered.
usleep(30_000)
if !flags.isEmpty, let release = CGEvent(source: source) {
    release.type = .flagsChanged
    release.flags = []
    release.post(tap: .cghidEventTap)
}
