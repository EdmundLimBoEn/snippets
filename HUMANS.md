# Human actions

- [ ] Grant Accessibility to Snippets on first paste (System Settings → Privacy & Security → Accessibility).
- [ ] Set up keys in Settings (e.g. caps+Q emails, caps+W socials, caps+Z / caps+X sites).
- [ ] Smoke test: copy "SENTINEL", paste a snippet into TextEdit/Notes/Chrome with the caps-lock Hyper key, then ⌘V should still give "SENTINEL".
- [ ] Turn on Settings → General → Launch at login, then confirm Snippets starts after logging out and back in.
- [ ] Re-record an already-assigned shortcut once in Settings to confirm the recorder captures it (review flagged a possible clash).
- [ ] After granting Accessibility, quit Snippets and run `./scripts/e2e.sh` (auto-pastes into TextEdit and checks the clipboard is restored).
