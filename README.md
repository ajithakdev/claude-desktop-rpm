# claude-desktop-fedora

Every link and how-to is in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

Run Anthropic's Claude Desktop (Linux beta) on Fedora. Anthropic only ships a `.deb` for Ubuntu and Debian. This script downloads that package from Anthropic, verifies it, and unpacks it into `~/.local`.

Unofficial and not affiliated with Anthropic. The repo holds one shell script and no Anthropic files.

## Install

```bash
sudo dnf install curl gnupg2 binutils tar
git clone https://github.com/ajithakdev/claude-desktop-fedora
cd claude-desktop-fedora
./claude-desktop-fedora.sh install
```

Open Claude from the app menu and sign in. The app itself needs no sudo.

## Commands

| Command | Effect |
| --- | --- |
| `install`, `update` | Install the newest version. Does nothing if it is already current. |
| `update --force` | Reinstall the current version. |
| `cowork` | Set up the Cowork tab (uses sudo). |
| `version` | Print the installed version. |
| `uninstall` | Remove the app. Your sign-in and chats in `~/.config/Claude` stay. |

The app does not update itself. Quit it, then run `update`.

## Cowork

Cowork runs tasks in a QEMU/KVM virtual machine. Turn on SVM or VT-x in your BIOS, then run:

```bash
./claude-desktop-fedora.sh cowork
```

It installs `qemu-system-x86-core`, `edk2-ovmf` and `virtiofsd`, loads `vhost_vsock` at boot, and adds you to the `kvm` group. Log out and back in afterwards. The first Cowork task downloads the VM image, so it starts slowly.

The app looks for UEFI firmware only at Debian's path, so the script also links Fedora's files there:

```
/usr/share/OVMF/OVMF_CODE.fd -> /usr/share/edk2/ovmf/OVMF_CODE.fd
/usr/share/OVMF/OVMF_VARS.fd -> /usr/share/edk2/ovmf/OVMF_VARS.fd
```

## Verification

The script stops on any failed check:

1. The signing key fingerprint must be `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.
2. The repository's `InRelease` signature must verify against that key.
3. The `Packages` index must match the checksum in `InRelease`.
4. The `.deb` must match the checksum in `Packages`.

## Files

- `~/.local/lib/claude-desktop/`: the app
- `~/.local/bin/claude-desktop`: the launcher
- `~/.local/share/applications/com.anthropic.Claude.desktop`: the menu entry and `claude://` handler, which sign-in needs
- `~/.local/share/icons/hicolor/`: icons

## Limits

- Tested on Fedora 44 with GNOME on Wayland, x86_64. aarch64 is untested, and `cowork` is x86_64 only.
- Anthropic does not support Fedora, so a new release can break this script.
- The GNOME search provider and the AppArmor profile from the `.deb` are not installed.
- The Linux beta has no Computer Use or dictation.

## License

MIT for the script. Claude Desktop is Anthropic's software under Anthropic's terms.
