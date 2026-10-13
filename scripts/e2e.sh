#!/bin/bash
# Exit 0 = pass, 1 = failure, 77 = blocked by a prerequisite/permission.
set -Eeuo pipefail
umask 077
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DATA_DIR="$HOME/Library/Application Support/Snippets"
DATA="$DATA_DIR/snippets.json"
DERIVED="$ROOT/build/e2e"
APP="$DERIVED/Build/Products/Debug/Snippets.app"
WORK="" BACKUP="" DOC_ID="" APP_PID=""
INSTALLED=0 HAD_DATA=0 CLIP_SAVED=0 LOCKED=0
LOCK="$DATA_DIR/.e2e-lock"
pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
blocked() { printf 'BLOCKED: %s\n' "$*" >&2; exit 77; }
permission_hint() {
    printf '%s\n' 'Accessibility: System Settings > Privacy & Security > Accessibility.' \
      "Enable Snippets ($APP), plus your terminal/host (Terminal, iTerm, or T3 Code) and keys helper if listed; restart and rerun." \
      'Pane: x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility' >&2
}
cleanup() {
    local rc=$?
    trap - EXIT ERR INT TERM HUP
    set +e
    if [[ -n "$APP_PID" ]]; then
        kill -TERM "$APP_PID" 2>/dev/null
        for ((i=0; i<30; i++)); do
            kill -0 "$APP_PID" 2>/dev/null || break
            sleep 0.1
        done
        if kill -0 "$APP_PID" 2>/dev/null; then kill -KILL "$APP_PID" 2>/dev/null; fi
        wait "$APP_PID" 2>/dev/null
    fi
    if [[ -n "$DOC_ID" ]]; then
        if osascript - "$DOC_ID" <<'APPLESCRIPT'
on run argv
    tell application "TextEdit"
        close (document named (item 1 of argv)) saving no
    end tell
end run
APPLESCRIPT
        then pass 'closed only the E2E TextEdit document without saving'
        else printf 'FAIL: close the E2E TextEdit document manually\n' >&2; rc=1; fi
    fi
    if [[ "$CLIP_SAVED" == 1 ]]; then
        if "$ROOT/scripts/e2e/.bin/clipboard" restore "$WORK/clipboard.plist"; then
            pass 'restored original clipboard'
        else rc=1; fi
    fi
    if [[ "$INSTALLED" == 1 ]]; then
        if [[ "$HAD_DATA" == 1 ]]; then
            if cp -p "$BACKUP" "$DATA" && cmp -s "$BACKUP" "$DATA"; then
                pass "restored original snippets.json; backup retained: $BACKUP"
            else printf 'FAIL: restore snippets.json manually from %s\n' "$BACKUP" >&2; rc=1; fi
        elif [[ -f "$DATA" ]]; then
            # Preserve the fixture too; never delete a potentially edited data file.
            if mv "$DATA" "$DATA.e2e-result-$(date +%Y%m%d-%H%M%S)-$$"; then
                pass 'restored original absent-file state; E2E data retained alongside it'
            else rc=1; fi
        fi
    fi
    [[ "$LOCKED" == 0 ]] || rmdir "$LOCK" || rc=1
    # WORK contains only this run's source copy and clipboard snapshot.
    [[ -z "$WORK" ]] || rm -rf "$WORK"
    if [[ "$rc" == 0 ]]; then pass 'E2E smoke test complete';
    elif [[ "$rc" == 77 ]]; then printf 'BLOCKED: E2E smoke test incomplete\n' >&2;
    else printf 'FAIL: E2E smoke test incomplete\n' >&2; fi
    exit "$rc"
}
trap cleanup EXIT
trap 'printf "FAIL: command at line %s (exit %s)\n" "$LINENO" "$?" >&2' ERR
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
[[ "$(uname)" == Darwin ]] || blocked 'requires macOS and a logged-in graphical session'
for tool in swift swiftc xcodegen xcodebuild osascript pbcopy pbpaste; do
    command -v "$tool" >/dev/null || blocked "missing $tool"
done
mkdir -p "$DATA_DIR"
mkdir "$LOCK" 2>/dev/null || blocked "another run is active, or a stale lock remains at $LOCK; check before removing it"
LOCKED=1
WORK=$(mktemp -d "${TMPDIR:-/tmp}/snippets-e2e.XXXXXX")
mkdir -p "$ROOT/scripts/e2e/.bin"
for helper in make_fixture keys clipboard; do
    swiftc "$ROOT/scripts/e2e/$helper.swift" -o "$ROOT/scripts/e2e/.bin/$helper"
done
pass 'all three standalone Swift helpers compiled'
# Generate via the Swift interpreter as well as checking standalone compilation.
swift "$ROOT/scripts/e2e/make_fixture.swift" "$WORK/fixture.json"
for ((i=0; i<240; i++)); do
    [[ -f "$ROOT/Snippets/Store.swift" && -f "$ROOT/project.yml" ]] && break
    (( i % 12 != 0 )) || printf 'WAIT: app source/project (up to 20 minutes)\n'
    sleep 5
done
[[ -f "$ROOT/Snippets/Store.swift" && -f "$ROOT/project.yml" ]] || blocked 'app sources did not arrive within 20 minutes'
# XcodeGen writes Info.plist; use a snapshot to avoid altering other agents' files.
mkdir "$WORK/source"
cp "$ROOT/project.yml" "$WORK/source/"
cp -R "$ROOT/Snippets" "$WORK/source/"
[[ ! -d "$ROOT/SnippetsTests" ]] || cp -R "$ROOT/SnippetsTests" "$WORK/source/"
(cd "$WORK/source" && xcodegen generate)
pass 'XcodeGen project generation in isolated source copy'
xcodebuild -project "$WORK/source/Snippets.xcodeproj" -scheme Snippets \
    -configuration Debug -destination 'platform=macOS' -derivedDataPath "$DERIVED" build | tail -60
[[ -x "$APP/Contents/MacOS/Snippets" ]] || fail 'build did not produce Snippets.app'
pass 'Debug app build'
"$ROOT/scripts/e2e/.bin/keys" --check
pgrep -x Snippets >/dev/null && blocked 'quit the existing Snippets app, then rerun; no live data was replaced'
if [[ -e "$DATA" || -L "$DATA" ]]; then
    [[ -f "$DATA" && ! -L "$DATA" ]] || blocked 'snippets.json is not a regular non-symlink file'
    BACKUP="$DATA.e2e-backup-$(date +%Y%m%d-%H%M%S)-$$"
    cp -p "$DATA" "$BACKUP"
    cmp -s "$DATA" "$BACKUP" || fail 'backup verification'
    HAD_DATA=1
    pass "backed up user data: $BACKUP"
else
    pass 'no existing snippets.json; absent-file state will be restored'
fi
INSTALLED=1
cp "$WORK/fixture.json" "$DATA"
pass 'installed E2E fixture'
"$APP/Contents/MacOS/Snippets" &
APP_PID=$!
sleep 2
kill -0 "$APP_PID" 2>/dev/null || fail 'Snippets exited during launch'
pass 'launched built Snippets.app'
if ! DOC_ID=$(osascript <<'APPLESCRIPT'
tell application "TextEdit"
    activate
    set testDoc to make new document with properties {text:""}
    return name of testDoc
end tell
APPLESCRIPT
); then
    blocked 'allow terminal/host to control TextEdit in System Settings > Privacy & Security > Automation'
fi
[[ -n "$DOC_ID" ]] || fail 'TextEdit did not return the test document name'
pass 'created a blank TextEdit document (existing documents preserved)'
read_doc() {
    osascript - "$DOC_ID" <<'APPLESCRIPT'
on run argv
    tell application "TextEdit" to get text of (document named (item 1 of argv))
end run
APPLESCRIPT
}
wait_text() {
    local expected=$1 actual
    for ((attempt=0; attempt<30; attempt++)); do
        actual=$(read_doc) || return 1
        [[ "$actual" == "$expected" ]] && return 0
        sleep 0.2
    done
    printf 'FAIL: expected TextEdit text <%s>; got <%s>\n' "$expected" "$actual" >&2
    return 1
}
"$ROOT/scripts/e2e/.bin/clipboard" save "$WORK/clipboard.plist"
CLIP_SAVED=1
printf SENTINEL | pbcopy
sleep 0.5
"$ROOT/scripts/e2e/.bin/keys" hyper 29
if ! wait_text E2E-ALPHA; then
    permission_hint
    if [[ "$(pbpaste)" == E2E-ALPHA ]]; then
        blocked 'Snippets copied ALPHA but did not paste/restore; consistent with its Accessibility-denied copy-only fallback'
    fi
    fail 'direct paste failed; runner preflight passed, so app permission, focus, or hotkey handling needs investigation'
fi
pass 'Hyper+0 pasted E2E-ALPHA'
sleep 1
[[ "$(pbpaste)" == SENTINEL ]] || fail 'clipboard was not SENTINEL after direct paste'
pass 'clipboard restored to SENTINEL after direct paste'
"$ROOT/scripts/e2e/.bin/keys" hyper 25
sleep 0.7
"$ROOT/scripts/e2e/.bin/keys" plain 19
if ! wait_text E2E-ALPHAE2E-CHARLIE; then
    permission_hint
    fail 'Hyper+9 then 2 did not append CHARLIE (picker/focus/paste failure)'
fi
pass 'Hyper+9 picker, digit 2 appended E2E-CHARLIE'
sleep 1
[[ "$(pbpaste)" == SENTINEL ]] || fail 'clipboard was not SENTINEL after picker paste'
pass 'clipboard restored to SENTINEL after picker paste'
