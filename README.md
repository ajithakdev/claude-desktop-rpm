# claude-desktop-rpm

[![CI](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml/badge.svg)](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ajithakdev/claude-desktop-rpm)](https://github.com/ajithakdev/claude-desktop-rpm/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Every link and how-to is in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

Run Anthropic's Claude Desktop (Linux beta) on Fedora. Anthropic only ships a `.deb` for Ubuntu and Debian. This script downloads that package from Anthropic, verifies it, unpacks it into `~/.local`, and keeps it up to date.

The app itself is Anthropic's, byte for byte: nothing inside it is patched. The repo holds one shell script and no Anthropic files. Unofficial and not affiliated with Anthropic.

## Install

```bash
sudo dnf install curl gnupg2 binutils tar
curl -fLO https://github.com/ajithakdev/claude-desktop-rpm/releases/latest/download/claude-desktop-rpm.sh
chmod +x claude-desktop-rpm.sh
./claude-desktop-rpm.sh install
```

Open Claude from the app menu and sign in. Then run `claude-desktop-rpm doctor` to see if anything else needs setting up. The install copies the script to `~/.local/bin/claude-desktop-rpm`, so from now on you can run it from anywhere.

Run it as your normal user. The app refuses to run as root, and only `cowork` asks for sudo.

## Updates

Install turns on a daily check (a systemd user timer). When Anthropic publishes a new version:

- If Claude is closed, it installs right away.
- If Claude is open, it downloads and verifies the update, then installs it the next time you open Claude. That takes a few seconds and needs no network.

You get a desktop notification either way. The app's own "Update available" button links to Anthropic's apt instructions, which don't apply on Fedora; ignore it, or quit Claude and run `claude-desktop-rpm update` to update now.

Turn the timer off with `claude-desktop-rpm auto-update off`.

## Commands

| Command | Effect |
| --- | --- |
| `install`, `update` | Install the newest version. Does nothing if it is already current. |
| `update --force` | Reinstall the current version. |
| `auto-update on`, `off` | Turn the daily update check on or off. With no argument, show its state. |
| `doctor` | Check the install, tray icon, keyring, Quick Entry hotkey and Cowork, and say how to fix each problem. |
| `cowork` | Set up the Cowork tab (uses sudo). |
| `version` | Print the installed version. |
| `uninstall` | Remove the app, launcher, timer and search provider. Your sign-in and chats in `~/.config/Claude` stay. |

## What it fixes for Fedora

- **Dark mode.** The System theme should follow GNOME's Settings > Appearance > Style, but Electron reads only the GTK theme name and ignores that switch. The launcher checks the style each time Claude starts and sets `GTK_THEME=Adwaita:dark` when it is dark. After switching styles, quit and reopen Claude. Set `GTK_THEME` yourself and the launcher leaves it alone.
- **Cowork firmware.** The app looks for UEFI firmware only at Debian's path, so `cowork` links Fedora's files there:
  ```
  /usr/share/OVMF/OVMF_CODE.fd -> /usr/share/edk2/ovmf/OVMF_CODE.fd
  /usr/share/OVMF/OVMF_VARS.fd -> /usr/share/edk2/ovmf/OVMF_VARS.fd
  ```
- **GNOME search.** Anthropic's search provider is installed, so your Claude sessions show up in the Activities search.
- **Tray icon.** GNOME hides tray icons, and Claude's tray menu holds Quit. `install` and `doctor` tell you how to turn on the AppIndicator extension if it is off.

## Cowork

Cowork runs tasks in a QEMU/KVM virtual machine. Turn on SVM or VT-x in your BIOS, then run:

```bash
claude-desktop-rpm cowork
```

It installs `qemu-system-x86-core`, `edk2-ovmf` and `virtiofsd`, links the firmware (above), loads `vhost_vsock` at boot, and adds you to the `kvm` group. Log out and back in afterwards. The first Cowork task downloads the VM image, so it starts slowly.

## Verification

Every install and update stops on any failed check:

1. The signing key fingerprint must be `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.
2. The repository's `InRelease` signature must verify against that key.
3. `InRelease` must not be past its `Valid-Until` date, so an old signed index can't be replayed to hold you on an old version.
4. The `Packages` index must match the checksum in `InRelease`.
5. The `.deb` must match the checksum in `Packages`.

## Files

- `~/.local/lib/claude-desktop/`: the app
- `~/.local/bin/claude-desktop`: the launcher (dark mode, staged updates)
- `~/.local/bin/claude-desktop-rpm`: this script
- `~/.local/share/applications/com.anthropic.Claude.desktop`: the menu entry and `claude://` handler, which sign-in needs
- `~/.local/share/gnome-shell/search-providers/` and `~/.local/share/dbus-1/services/`: the search provider
- `~/.local/share/icons/hicolor/`: icons
- `~/.config/systemd/user/claude-desktop-rpm-update.{service,timer}`: the daily update check

## Testing

`tests/e2e.sh` installs from Anthropic into a temporary folder and checks every command, including an update that arrives while Claude is open, without touching your install. CI runs it on every push and every Monday, so a change on Anthropic's side shows up quickly. The release checklist is in [docs/TESTING.md](docs/TESTING.md).

## Limits

- Tested on Fedora 44 with GNOME on Wayland, x86_64. aarch64 is untested, and `cowork` is x86_64 only.
- Anthropic does not support Fedora, so a new release can break this script. The weekly CI run is there to catch that.
- The AppArmor profile from the `.deb` is not installed (Fedora uses SELinux).
- Anthropic's Linux beta has no Computer Use or dictation, on any distribution.

## Moving from claude-desktop-fedora

This repo used to be called claude-desktop-fedora. Your install in `~/.local` stays where it is. Quit Claude, then run `./claude-desktop-rpm.sh update --force` once to get the new launcher, the timer and the search provider.

## Contributing and security

See [CONTRIBUTING](.github/CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). Changes are listed in [CHANGELOG.md](CHANGELOG.md).

## License

MIT for the script. Claude Desktop is Anthropic's software under Anthropic's terms.
