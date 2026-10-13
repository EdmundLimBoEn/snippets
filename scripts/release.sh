#!/bin/bash
set -euo pipefail
umask 077
: "${GITHUB_RUN_NUMBER:?Run this through the Release workflow}"
version="1.0.$GITHUB_RUN_NUMBER"
tag="v$version"
work=$(mktemp -d)
keychain="$work/release.keychain-db"
keychain_password=$(openssl rand -hex 32)
cleanup() {
  security delete-keychain "$keychain" >/dev/null 2>&1 || true
  rm -rf "$work"
}
trap cleanup EXIT
printf '%s' "$DEVELOPER_ID_P12_BASE64" | base64 --decode > "$work/certificate.p12"
printf '%s' "$ASC_API_KEY_P8" > "$work/AuthKey.p8"
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$work/sparkle-key"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$work/certificate.p12" -k "$keychain" -P "$DEVELOPER_ID_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
identity=$(security find-identity -v -p codesigning "$keychain" | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -1)
if [[ -z "$identity" ]]; then
  echo '::error::The P12 must contain a valid Developer ID Application certificate and its private key.'
  exit 1
fi
[[ "$identity" == *'(DUU8J39BA7)' ]] || { echo '::error::Developer ID certificate must belong to team DUU8J39BA7.'; exit 1; }

# Archive/export is Sparkle's recommended distribution path for its nested helpers.
xcodebuild -scheme Snippets -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/ci -archivePath "$work/Snippets.xcarchive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" \
  DEVELOPMENT_TEAM=DUU8J39BA7 OTHER_CODE_SIGN_FLAGS="--timestamp" \
  ENABLE_HARDENED_RUNTIME=YES ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CURRENT_PROJECT_VERSION="$GITHUB_RUN_NUMBER" MARKETING_VERSION="$version" archive
cat > "$work/export.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>DUU8J39BA7</string>
<key>signingStyle</key><string>manual</string>
<key>signingCertificate</key><string>Developer ID Application</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$work/Snippets.xcarchive" \
  -exportPath "$work/export" -exportOptionsPlist "$work/export.plist"
app="$work/export/Snippets.app"
framework="$app/Contents/Frameworks/Sparkle.framework"
# Sign inside out; retain Sparkle's shipped helper entitlements. Never use --deep to sign.
while IFS= read -r -d '' helper; do
  codesign --force --sign "$identity" --options runtime --timestamp --preserve-metadata=entitlements "$helper"
done < <(find "$framework/Versions/B" \( -name '*.xpc' -o -name Autoupdate \) -print0)
codesign --force --sign "$identity" --options runtime --timestamp --preserve-metadata=entitlements "$framework/Versions/B/Updater.app"
codesign --force --sign "$identity" --options runtime --timestamp "$framework"
codesign --force --sign "$identity" --options runtime --timestamp "$app"
codesign --verify --deep --strict --verbose=2 "$app"

notarize() {
  xcrun notarytool submit "$1" --key "$work/AuthKey.p8" --key-id "$ASC_KEY_ID" \
    --issuer "$ASC_ISSUER_ID" --wait --output-format json > "$work/notary-result.json"
  if ! python3 -c 'import json,sys; sys.exit(json.load(open(sys.argv[1]))["status"] != "Accepted")' "$work/notary-result.json"; then
    submission=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["id"])' "$work/notary-result.json")
    xcrun notarytool log "$submission" --key "$work/AuthKey.p8" --key-id "$ASC_KEY_ID" --issuer "$ASC_ISSUER_ID"
    echo '::error::Notarization rejected; see the log above.'
    exit 1
  fi
}
ditto -c -k --keepParent "$app" "$work/Snippets.zip"
notarize "$work/Snippets.zip"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
mkdir -p "$work/dmg" build/release
ditto "$app" "$work/dmg/Snippets.app"
ln -s /Applications "$work/dmg/Applications"
hdiutil create -volname Snippets -srcfolder "$work/dmg" -ov -format UDZO build/release/Snippets.dmg
codesign --sign "$identity" --timestamp build/release/Snippets.dmg
notarize build/release/Snippets.dmg
xcrun stapler staple build/release/Snippets.dmg
xcrun stapler validate build/release/Snippets.dmg
codesign --verify --verbose=2 build/release/Snippets.dmg

# Use the tools resolved with the app so framework and update signatures stay in sync.
sign_update="build/ci/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update"
test -n "$sign_update"
signature=$("$sign_update" --ed-key-file "$work/sparkle-key" -p build/release/Snippets.dmg)
"$sign_update" --ed-key-file "$work/sparkle-key" --verify build/release/Snippets.dmg "$signature"
python3 scripts/make-appcast.py "$GITHUB_RUN_NUMBER" "$signature" build/release/Snippets.dmg build/release/appcast.xml
# Upload both assets before making the release visible to latest/download clients.
gh release create "$tag" build/release/Snippets.dmg build/release/appcast.xml \
  --repo EdmundLimBoEn/snippets --target "$GITHUB_SHA" --draft --title "Snippets $version" \
  --notes "Signed and notarized universal macOS app. Requires macOS 26 or later.

Written by gpt-6.1-sol in Codex on behalf of Edmund"
gh release edit "$tag" --repo EdmundLimBoEn/snippets --draft=false --latest
