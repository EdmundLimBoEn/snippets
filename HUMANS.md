# Human actions

- [ ] Grant Accessibility to Snippets on first paste (System Settings → Privacy & Security → Accessibility).
- [ ] Set up keys in Settings (e.g. caps+Q emails, caps+W socials, caps+Z / caps+X sites).
- [ ] Smoke test: copy "SENTINEL", paste a snippet into TextEdit/Notes/Chrome with the caps-lock Hyper key, then ⌘V should still give "SENTINEL".
- [ ] Turn on Settings → General → Launch at login, then confirm Snippets starts after logging out and back in.
- [ ] In Settings, click a key's shortcut pill and press physical caps lock + a letter to confirm the new recorder captures the Karabiner Hyper chord.
- [ ] After granting Accessibility, quit Snippets and run `./scripts/e2e.sh` (auto-pastes into TextEdit and checks the clipboard is restored).
- [ ] Xcode → Settings → Accounts → your team → Manage Certificates → + → Developer ID Application, then tell Claude so it can export the P12, set the signing secrets and run the first release (manual route: [release setup](docs/releases.md)).
- [ ] After the first release, verify public download access when the repository is made public and test Sparkle between two published versions.
