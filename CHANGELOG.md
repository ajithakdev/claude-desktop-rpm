# Changelog

All notable changes to claude-desktop-rpm. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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

[Unreleased]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/ajithakdev/claude-desktop-rpm/releases/tag/v1.0.0
