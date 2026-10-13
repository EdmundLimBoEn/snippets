#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
if build_output=$(xcodebuild -project Snippets.xcodeproj -scheme Snippets \
  -configuration Release -destination 'platform=macOS' \
  -derivedDataPath build/release build 2>&1); then
  printf '%s\n' "$build_output" | tail -n 5
else
  printf '%s\n' "$build_output" | tail -n 60 >&2
  exit 1
fi
if pgrep -x Snippets >/dev/null; then
  osascript -e 'tell application id "com.edmundlim.snippets" to quit' || true
  for _ in {1..5}; do
    pgrep -x Snippets >/dev/null || break
    sleep 1
  done
  if pgrep -x Snippets >/dev/null; then
    pkill -x Snippets || true
    sleep 1
  fi
  if pgrep -x Snippets >/dev/null; then
    echo 'ERROR: Snippets is still running; installation aborted.' >&2
    exit 1
  fi
fi
[[ -d build/release/Build/Products/Release/Snippets.app ]]
rm -rf /Applications/Snippets.app
ditto build/release/Build/Products/Release/Snippets.app /Applications/Snippets.app
codesign --verify --deep --strict /Applications/Snippets.app
signature=$(codesign -dv --verbose=2 /Applications/Snippets.app 2>&1)
printf '%s\n' "$signature" | awk '/^Authority=|^TeamIdentifier=|^Signature=/'
if [[ "$signature" == *'Signature=adhoc'* ]]; then
  echo 'WARNING: AD-HOC SIGNING! Accessibility permission resets on every install.' >&2
elif [[ "$signature" != *'Authority=Apple Development:'* || "$signature" != *'TeamIdentifier=DUU8J39BA7'* ]]; then
  echo 'WARNING: Expected Apple Development signing with team DUU8J39BA7; check signing identity.' >&2
fi
open /Applications/Snippets.app
echo 'First install: grant Snippets access in System Settings → Privacy & Security → Accessibility.'
