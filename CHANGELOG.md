# Changelog

All notable changes to claude-desktop-rpm. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-24

### Added
- `install` and `update`: download Claude Desktop from Anthropic's signed repository, check the signing key, signature and both checksums, and unpack it into `~/.local`. No root needed.
- `update --force` to reinstall the current version.
- `cowork` sets up the Cowork tab: QEMU, OVMF firmware linked at the path the app expects, `vhost_vsock` at boot, and `kvm` group membership.
- `uninstall` removes the app and keeps your sign-in and chats.
- `version` prints the installed version.

### Changed
- Renamed from claude-desktop-fedora. The script is now `claude-desktop-rpm.sh`.

[Unreleased]: https://github.com/ajithakdev/claude-desktop-rpm/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ajithakdev/claude-desktop-rpm/releases/tag/v1.0.0
