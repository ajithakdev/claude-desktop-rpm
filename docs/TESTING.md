# Testing checklist

Run the automated test first, then the manual checks that need a real desktop. Tick every box before tagging a release.

## Automated

```bash
shellcheck claude-desktop-rpm.sh tests/e2e.sh
tests/e2e.sh
```

`tests/e2e.sh` downloads the real package from Anthropic and installs it into a temporary folder, so it never touches `~/.local`. It checks:

- [ ] the signing key, `InRelease` signature and both checksums pass (any failure stops the install)
- [ ] the app, version file, launcher, menu entry, `claude://` handler, icons, search provider and the script's own copy are in place
- [ ] `update` does nothing when the version is current
- [ ] `version` prints the installed version
- [ ] the launcher sets `GTK_THEME=Adwaita:dark` when GNOME's style is dark, leaves it unset when light, and keeps a `GTK_THEME` you set yourself
- [ ] with Claude open, `update` refuses, `update --auto` stages the new version without touching the app, and does not download it twice
- [ ] `apply-staged` waits while Claude is open, then installs the staged version and clears the stage
- [ ] `doctor` runs
- [ ] `uninstall` removes the app, launcher, script copy, menu entry and search provider

CI runs the same script on every push and every Monday.

## Manual (on Fedora with a desktop)

- [ ] `./claude-desktop-rpm.sh install` finishes, and Claude shows up in the app menu
- [ ] Sign-in in the browser comes back to the app (tests the `claude://` handler)
- [ ] Settings > Appearance > System: dark when GNOME's style is Dark, light when Light (quit and reopen Claude after switching)
- [ ] Light and Dark buttons still work
- [ ] `claude-desktop-rpm doctor` shows no warnings you didn't expect
- [ ] `systemctl --user list-timers claude-desktop-rpm-update.timer` shows the next run; `auto-update off` removes it and `auto-update on` brings it back
- [ ] Run `systemctl --user start claude-desktop-rpm-update.service` with an older version installed and Claude open: a notification says the update is ready, and reopening Claude starts the new version
- [ ] GNOME Activities search for a Claude session title shows it, and clicking it opens the session
- [ ] Quit Claude, run `update`: says up to date, or installs the new version
- [ ] `update` while Claude is running stops with "quit it first"
- [ ] `cowork`, log out and in, then a Cowork task starts
- [ ] `uninstall` removes the menu entry; `~/.config/Claude` is still there
