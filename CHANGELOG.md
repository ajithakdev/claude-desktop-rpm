# Changelog

All notable changes to claude-desktop-rpm. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- README rewrite: an animated banner, a Featured in Fedora Magazine badge, a full-width terminal image with real install and doctor output from Claude Desktop 5.11492.2, line icons in place of emoji, a step-by-step account of the verification, a How it works flowchart and the release and stats cards side by side. Animations stop when the system asks for reduced motion.

### Added
- `self-update`: replaces the script with the latest release after checking it against that release's `SHA256SUMS`. Until now, getting new commands such as `profile` meant downloading the script again by hand.

### Fixed
- A browser opened from a link in Claude (for example the update notice) showed up as Claude: its windows sat under Claude's dock icon, and its "make default browser" button made Claude your default browser. Electron passes its `CHROME_DESKTOP` to every program it opens, so the launcher now opens links through a small `xdg-open` that drops it. If this already happened to you, set your browser as default again in Settings > Apps > Default Apps.
- GNOME no longer shows an "Add Keyboard Shortcuts" prompt for Ctrl+Alt+Space every time Claude (or a second profile) starts. The launcher skips the app's request for that shortcut on GNOME, where it never fired anyway.

## [1.2.0] - 2026-11-10

### Added
- `profile add NAME`, `profile remove NAME` and `profile list`: run a second Claude account side by side, each with its own menu entry and data folder (`~/.config/Claude-NAME`). The launcher passes Chromium's `--user-data-dir`; Anthropic's files are untouched. Browser links go to the profile opened last.

### Changed
- README: a Support section with Ko-fi and a UPI ID, and a Sponsor button for both.
- README: a daily release card (version, newest Claude Desktop, tested desktops), a stats card with daily bars for stars and downloads, round profile pictures in Credits, a Follow badge in place of Stars, and a short list of my other projects.
- KDE Plasma 6.7 is listed as reported working (#2), and the guide has a fix for the app's monospace UI font on KDE.
- The FAQ no longer lists dictation as missing; it works in Claude Desktop 3.6556.2 on Fedora.
- README: a Downloads badge is back next to Stars (its total also counts `SHA256SUMS` downloads, a few percent), the nav links Commands, and the intro is tighter.
- The README is about half as long: each fact appears once, troubleshooting lives in the guide, and a terminal image of a real install and `doctor` run replaces the old screenshot at the top (the screenshot is still there, folded under Install).
- A daily stats card shows stars over time and script downloads per release, in light and dark.

## [1.1.3] - 2026-10-27

To upgrade, download the new script and run `./claude-desktop-rpm.sh install` once; the daily timer updates the app, not this script. If you ran `cowork` before, run `claude-desktop-rpm cowork` again to put Fedora's firmware links back (`rpm -V edk2-ovmf` then prints nothing).

### Fixed
- `cowork` no longer replaces the firmware links in `/usr/share/OVMF`. Fedora's `edk2-ovmf` package already ships them, and the old step made `rpm -V edk2-ovmf` fail. If an older release changed them, `cowork` puts the packaged links back with `dnf reinstall edk2-ovmf`, and `doctor` warns until it does (#8). Found while following the Fedora Magazine writing guidelines during the editors' review.
- `uninstall` now rebuilds the file-type and icon caches, so `.mcpb` and `.skill` files no longer stay registered to Claude after it is removed.

### Added
- `tests/guidelines.sh`: checks the script and docs against Fedora's rules (no changes under `/usr`, Fedora packages only, licensing and AI disclosure, Fedora Magazine writing style, working links).
- `tests/sandbox.sh`: installs, uninstalls and runs `cowork` in a fresh Fedora 44 container as a normal user. CI runs both.
- The script carries an SPDX license header.

### Changed
- The README has a "What it changes on your system" section, and a FAQ entry for the "Hardware acceleration disabled" notice after a reboot.
- The README says which Claude plan each feature needs (Chat on Free; Claude Code and Cowork on paid plans) and that Claude Desktop is proprietary software from Anthropic (#9). Requested by Fedora Magazine editors Richard England and Justin Wheeler.

## [1.1.2] - 2026-10-25

### Fixed
- `install` no longer tells you to enable the AppIndicator extension when it is already on. The check sometimes failed because of how its pipe was written, so `doctor` and `install` could disagree.

## [1.1.1] - 2026-10-25

Security release (#7). To upgrade from 1.1.0, download the new script and run `./claude-desktop-rpm.sh install` once. The daily timer updates the app, not this script.

### Added
- `tests/mock-repo.sh`: attack tests that run full installs against a fake repository with tampered signatures, checksums, expiry dates and versions. CI runs them on every PR.
- Releases are published by a workflow when a `vX.Y.Z` tag is pushed. Each release attaches a `SHA256SUMS` file for the script.

### Fixed
- Security: the repository index now has to be signed by Anthropic's pinned key itself. Before, the script checked that `key.asc` contained that key but accepted a signature from any key in the file, so a tampered `key.asc` with a second key could sign a fake index. Reported by Marko Jokinen on Fedora Discussion.
- A signature from an expired or revoked Anthropic key is refused, and so is an index without a `Valid-Until` date.
- `update` refuses to install an older version than the one installed, so a replayed index can't roll the app back. `update --force` still can.
- Downloads time out on dead connections instead of hanging the update timer, and never follow a redirect off HTTPS.

## [1.1.0] - 2026-10-24

### Added
- Automatic updates. A daily systemd user timer checks Anthropic's repository. If Claude is closed, the update installs right away; if it is open, the update is downloaded and verified, then installed the next time you open Claude. Turn it off with `auto-update off`.
- `doctor` checks the install, tray icon, keyring, Quick Entry hotkey and every Cowork requirement, and prints the fix for each problem.
- Anthropic's GNOME search provider is installed, so Claude sessions show up in the Activities search.
- `install` tells you how to turn on GNOME's AppIndicator extension when it is off, since Claude's tray menu holds Quit.
- The script copies itself to `~/.local/bin/claude-desktop-rpm`.
- `tests/e2e.sh` installs from Anthropic into a temporary folder and checks every command, including an update that arrives while Claude is open. CI runs it on each push and every Monday.
- `docs/TESTING.md`: the release checklist.

### Fixed
- The System theme now follows GNOME's dark style. Electron ignores that setting and reads only the GTK theme name, so the launcher sets `GTK_THEME=Adwaita:dark` when GNOME is dark.

### Security
- Installs and updates now refuse an `InRelease` index that is past its `Valid-Until` date, so an old signed index can't be replayed to keep you on an old version.
- The script refuses to run as root.

## [1.0.0] - 2026-10-24

### Added
- `install` and `update`: download Claude Desktop from Anthropic's signed repository, check the signing key, signature and both checksums, and unpack it into `~/.local`. No root needed.
- `update --force` to reinstall the current version.
- `cowork` sets up the Cowork tab: QEMU, OVMF firmware linked at the path the app expects, `vhost_vsock` at boot, and `kvm` group membership.
- `uninstall` removes the app and keeps your sign-in and chats.
- `version` prints the installed version.

### Changed
- Renamed from claude-desktop-fedora. The script is now `claude-desktop-rpm.sh`.

[Unreleased]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.1.3...v1.2.0
[1.1.3]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ajithakdev/claude-desktop-rpm/releases/tag/v1.0.0
