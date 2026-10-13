# Release setup

The Release workflow runs on `macos-26` for pushes to `main` and manual dispatch. It selects the newest non-beta installed Xcode and checks that its macOS SDK is at least 26. Tests run before a universal Release archive is built. Archive/export plus explicit inside-out signing covers Sparkle's XPC services, Autoupdate, Updater.app, framework, and the main app with hardened runtime and secure timestamps. When both Developer ID secrets exist, the app and DMG are separately notarized and stapled. Otherwise, the archive is copied directly and signed with the Apple Development identity; notarization and stapling are skipped. Both paths sign Sparkle helpers with the same identity, hardened runtime and timestamps. The team-based designated requirement is checked before packaging. Sparkle signs the final DMG, then a draft release receives both assets before publication.

Stable download: https://github.com/EdmundLimBoEn/snippets/releases/latest/download/Snippets.dmg

Stable feed: https://github.com/EdmundLimBoEn/snippets/releases/latest/download/appcast.xml

The feed points to an immutable `releases/download/v1.0.<run number>/Snippets.dmg`. Never delete published releases or reset the workflow's run counter. Rerunning a published run deliberately does not overwrite its assets; dispatch a new run instead.

## Secrets

The workflow validates the secrets required for the selected signing mode:

- `SPARKLE_PRIVATE_KEY`: exported Sparkle EdDSA key.
- `APPLE_DEV_P12_BASE64`, `APPLE_DEV_P12_PASSWORD`: Apple Development certificate and private key exported as a password-protected P12, required when either Developer ID secret is missing.
- `ASC_API_KEY_P8`, `ASC_KEY_ID`, `ASC_ISSUER_ID`: matching App Store Connect API credential, required only for Developer ID notarization.
- `DEVELOPER_ID_P12_BASE64`: base64 of a Developer ID Application certificate **with its private key**, team `DUU8J39BA7`.
- `DEVELOPER_ID_P12_PASSWORD`: password protecting that P12.

The Developer ID Application G2 certificate for team `DUU8J39BA7` was created on 2026-10-13 and expires on 2031-09-17. Both Developer ID secrets are configured. When exporting with OpenSSL 3, use `-keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1` for macOS Keychain compatibility; the default export failed with “MAC verification failed” despite the correct password. Verify the P12 imports into a temporary keychain before updating secrets, then remove the temporary keychain and P12.

Sparkle's key is also in the login keychain under account `snippets`. Do not regenerate it for routine releases; its public half is embedded in the app. To export a backup, use the Sparkle distribution's `bin/generate_keys --account snippets -x /secure/path/sparkle-key` and keep the exported file private.

The supplied `AuthKey_6G45YGP6ZU.p8` was rejected with the locally recorded issuer (`401 NOT_AUTHORIZED`). CI instead uses the existing locally configured, API-validated credential `U968QPQQ67`. Certificate creation with that credential was refused: “This operation can only be performed by the Account Holder.” Notarization succeeded for both the app and DMG in [run 38369215223](https://github.com/EdmundLimBoEn/snippets/actions/runs/38369215223), publishing [v1.0.7](https://github.com/EdmundLimBoEn/snippets/releases/tag/v1.0.7). Verification of the public download on 2026-10-13 confirmed `source=Notarized Developer ID` and successful `stapler validate` for both, strict app code-signature verification, a valid Sparkle EdDSA signature, and a working website download. The earlier v1.0.0 demo remains available in release history but is no longer latest.

## Certificate renewal and recovery

1. The Account Holder can authorise Edmund’s Admin role to create Developer ID certificates in App Store Connect → Users and Access, or create the certificate directly. Sign in at https://developer.apple.com/account/resources/certificates/list as Account Holder. Create a **Developer ID Application** certificate for team `DUU8J39BA7` (not Apple Development, Mac App Distribution, or Developer ID Installer).
2. A matching RSA private key and CSR were generated at `~/.private_keys/snippets/developer-id.key` and `developer-id.csr`. Upload that CSR and download the certificate. Alternatively create a CSR in Keychain Access, then use its matching private key.
3. If using the supplied CSR, import its private key and the downloaded certificate into the login keychain. Confirm a Developer ID Application identity appears in `security find-identity -v -p codesigning`. In Keychain Access → My Certificates, export the certificate **and private key** as a `.p12` protected with a strong password.
4. Set the two signing secrets (adjust the file path):

```sh
base64 < ~/Downloads/Snippets-Developer-ID.p12 | gh secret set DEVELOPER_ID_P12_BASE64 --repo EdmundLimBoEn/snippets
# Paste the P12 password when prompted; do not put it in shell history.
gh secret set DEVELOPER_ID_P12_PASSWORD --repo EdmundLimBoEn/snippets
gh workflow run release.yml --repo EdmundLimBoEn/snippets --ref main
```

If notarization rejects the API credential, create or locate a matching Team API key with sufficient access and set all three values together:

```sh
gh secret set ASC_API_KEY_P8 --repo EdmundLimBoEn/snippets < /secure/path/AuthKey_KEYID.p8
gh secret set ASC_KEY_ID --repo EdmundLimBoEn/snippets
gh secret set ASC_ISSUER_ID --repo EdmundLimBoEn/snippets
```

The repository is public. Verify the stable download URL without GitHub authentication. Finally test a real Sparkle upgrade between two published versions, including Accessibility permission after replacement.

## History review

Before this change, Gitleaks scanned all 30 commits including local checkpoint refs with redaction enabled and found no secrets. A separate all-ref text scan found no actual embedded email addresses, private keys, credentials, or absolute home paths (its email matches were `@2x.png` asset filenames). Commit metadata and planning documents identify Edmund by name and contain development notes; these are expected personal attribution, not credential leaks. The post-implementation scan flagged only the deliberately public Sparkle verification key in `project.yml`; `.gitleaks.toml` allowlists that exact public-key line. No history was rewritten.

Written by gpt-6-astra in Codex on behalf of Edmund
