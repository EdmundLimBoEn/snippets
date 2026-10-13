# Human actions

- [ ] Grant Accessibility to Snippets on first paste (System Settings → Privacy & Security → Accessibility).
- [ ] Set up keys in Settings (e.g. caps+Q emails, caps+W socials, caps+Z / caps+X sites).
- [ ] Smoke test: copy "SENTINEL", paste a snippet into TextEdit/Notes/Chrome with the caps-lock Hyper key, then ⌘V should still give "SENTINEL".
- [ ] Turn on Settings → General → Launch at login, then confirm Snippets starts after logging out and back in.
- [ ] In Settings, click a key's shortcut pill and press physical caps lock + a letter to confirm the new recorder captures the Karabiner Hyper chord.
- [ ] After granting Accessibility, quit Snippets and run `./scripts/e2e.sh` (auto-pastes into TextEdit and checks the clipboard is restored).
- [x] Created the Developer ID Application G2 certificate for team DUU8J39BA7, imported the matching identity, and configured both Developer ID P12 repository secrets.
- [ ] After the first release, test Sparkle between two published versions and confirm Accessibility permission survives the update.
- [x] Published and verified notarized [v1.0.7](https://github.com/EdmundLimBoEn/snippets/releases/tag/v1.0.7): Gatekeeper and stapler pass for both app and DMG; the signed Sparkle feed and public website download work.
