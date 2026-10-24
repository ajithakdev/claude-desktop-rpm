# claude-desktop-rpm: resources and guide

Every link for the Claude Desktop Fedora installer, what it is for, and how to run it. Passwords and keys are never written here.

## TL;DR

- One Bash script installs Anthropic's official Claude Desktop (Linux beta) on Fedora into `~/.local`, after checking Anthropic's signature and checksums.
- Updates arrive by themselves every day. If Claude is open, the update waits and installs the next time you open it.
- Something wrong? Run `claude-desktop-rpm doctor`. It says what to fix.
- Cowork needs `claude-desktop-rpm cowork` once, then log out and in.
- Releases: tag `vX.Y.Z` and attach the script (steps below).

## Links and what each one is for

### Public

| Link | Use it for |
| --- | --- |
| https://github.com/ajithakdev/claude-desktop-rpm | Source code and installation instructions |
| https://github.com/ajithakdev/claude-desktop-rpm/releases | Releases; each one has the script attached |
| https://github.com/ajithakdev/claude-desktop-rpm/releases/latest/download/claude-desktop-rpm.sh | Direct download of the latest script |
| https://code.claude.com/docs/en/desktop-linux | Anthropic's official Linux docs (Debian and Ubuntu) |

### Behind the scenes

| Link | Use it for |
| --- | --- |
| https://github.com/ajithakdev/claude-desktop-rpm/actions | CI: ShellCheck and the end-to-end install, every push and every Monday |
| https://downloads.claude.ai/claude-desktop/apt/stable | Anthropic's package repository |
| https://downloads.claude.ai/claude-desktop/key.asc | Anthropic's signing key (fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`) |

## Accounts

| Service | Account | Role |
| --- | --- | --- |
| GitHub | `ajithakdev` | Owner |

## User guide

1. **Install.** Download the script from the latest release, then run `./claude-desktop-rpm.sh install`. Open Claude from the app menu and sign in.
2. **Check setup.** Run `claude-desktop-rpm doctor` and follow any fix it prints.
3. **Dark mode.** Pick System in Claude's settings. It follows GNOME's style each time Claude starts; after switching styles, quit and reopen Claude.
4. **Update now.** Quit Claude (tray icon > Quit), then run `claude-desktop-rpm update`. Normally you don't need to: the daily check does it.
5. **Cowork.** Run `claude-desktop-rpm cowork`, then log out and in.
6. **Remove.** Quit Claude, then run `claude-desktop-rpm uninstall`. Your chats and sign-in stay in `~/.config/Claude`.

## Admin guide

| Job | How |
| --- | --- |
| Install dependencies | `sudo dnf install curl gnupg2 binutils tar` |
| Force reinstall | `claude-desktop-rpm update --force` |
| Auto-update on, off, state | `claude-desktop-rpm auto-update on`, `off`, or no argument |
| See the next update check | `systemctl --user list-timers claude-desktop-rpm-update.timer` |
| Update log | `journalctl --user -u claude-desktop-rpm-update` |
| Lint | `shellcheck claude-desktop-rpm.sh tests/e2e.sh` |
| Test end to end | `tests/e2e.sh` (installs into a temp folder, never touches `~/.local`) |
| Manual checklist | [docs/TESTING.md](docs/TESTING.md) |
| Release | Tick docs/TESTING.md. Move Unreleased in CHANGELOG.md to `## [X.Y.Z] - date`, commit `chore: release vX.Y.Z`, tag `vX.Y.Z`, push the tag, then `gh release create vX.Y.Z claude-desktop-rpm.sh --title vX.Y.Z --notes "<that section>"` |

## Files it writes

| Path | What |
| --- | --- |
| `~/.local/lib/claude-desktop/` | The app, unmodified |
| `~/.local/lib/claude-desktop.staged/` | An update waiting for the next launch (only while one waits) |
| `~/.local/bin/claude-desktop` | Launcher: dark mode, staged updates |
| `~/.local/bin/claude-desktop-rpm` | This script |
| `~/.local/bin/ccd` | Anthropic's `ccd` helper, linked from the app |
| `~/.local/share/applications/com.anthropic.Claude.desktop` | Menu entry and `claude://` handler (sign-in needs it) |
| `~/.local/share/mime/packages/com.anthropic.Claude.xml` | File types (`.mcpb`, `.skill`) |
| `~/.local/share/icons/hicolor/*/apps/claude-desktop.png` | Icons |
| `~/.local/share/gnome-shell/search-providers/`, `~/.local/share/dbus-1/services/` | GNOME search provider |
| `~/.config/systemd/user/claude-desktop-rpm-update.{service,timer}` | Daily update check |
| `~/.config/claude-desktop-rpm/no-auto-update` | Present only after `auto-update off` |
| `~/.config/Claude/` | Your chats and sign-in (the app's own; uninstall keeps it) |
| `/usr/share/OVMF/`, `/etc/modules-load.d/vhost_vsock.conf` | Written by `cowork` only (sudo) |

## When something goes wrong

| Problem | Fix |
| --- | --- |
| Not sure what's wrong | `claude-desktop-rpm doctor` |
| Missing tools | `sudo dnf install curl gnupg2 binutils tar coreutils` |
| "Claude Desktop is running" | Quit from the tray icon, then rerun. No tray icon on GNOME: see the next row |
| No tray icon on GNOME | `gnome-extensions enable appindicatorsupport@rgcjonas.gmail.com`. If that says it doesn't exist, first `sudo dnf install gnome-shell-extension-appindicator` (in a real terminal) and log out and in |
| System theme stays light | Run `claude-desktop-rpm update --force` once to get the new launcher, then reopen Claude |
| App says "Update available" | Its link points to apt. Ignore it, or quit Claude and run `claude-desktop-rpm update` |
| Signed out on every launch | Your keyring is missing or locked: `sudo dnf install gnome-keyring` and unlock it |
| Quick Entry hotkey does nothing on Wayland | Install your desktop's portal backend (`xdg-desktop-portal-gnome` or `-kde`) |
| `/dev/kvm` missing | Turn on SVM or VT-x in your BIOS |
| Cowork fails right after setup | Log out and back in so the `kvm` group applies |
| "index expired" | Anthropic's index is past its `Valid-Until` date; try again later |
| Verification fails | The script stops on a wrong key, bad signature or checksum. Don't work around it; open an issue |

## More detail

- [README.md](README.md): what the script does, Fedora fixes, verification, limits
- [docs/TESTING.md](docs/TESTING.md): release checklist
- [CHANGELOG.md](CHANGELOG.md): what changed in each release
- [SECURITY.md](SECURITY.md): what the script trusts and how to report a problem
- [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md): how to test a change
