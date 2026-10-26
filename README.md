<div align="center">

# claude-desktop-rpm

**Anthropic's official Claude Desktop on Fedora: verified, unmodified, and kept up to date.**

[![CI](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml/badge.svg)](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ajithakdev/claude-desktop-rpm)](https://github.com/ajithakdev/claude-desktop-rpm/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ajithakdev/claude-desktop-rpm/total)](https://github.com/ajithakdev/claude-desktop-rpm/releases)
[![Stars](https://img.shields.io/github/stars/ajithakdev/claude-desktop-rpm?style=flat)](https://github.com/ajithakdev/claude-desktop-rpm/stargazers)
[![Fedora 44](https://img.shields.io/badge/Fedora-44-51A2DA?logo=fedora&logoColor=white)](https://fedoraproject.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[Install](#install) · [Features](#features) · [What it changes](#what-it-changes-on-your-system) · [FAQ](#faq) · [Contributing](#contributing) · [Guide](RESOURCES-AND-GUIDE.md)

</div>

Anthropic ships Claude Desktop for Linux only as a `.deb` for Ubuntu and Debian. This one Bash script gets that same package from Anthropic, checks its signature and checksums, installs it into your home folder, and fixes the parts that don't work on Fedora out of the box: dark mode, Cowork, the tray icon and updates.

No root for the app, no third-party package repository, and no changes to Anthropic's files.

Claude Desktop is Anthropic's proprietary app, and you need a Claude account to use it. Chat works on every plan, including Free. Claude Code and Cowork need a paid plan (Pro, Max, Team or Enterprise), per Anthropic's [download FAQ](https://claude.com/download) and [plan table](https://support.claude.com/en/articles/10065433-install-claude-desktop). This script is MIT licensed and [not made by Anthropic](#faq), and it doesn't redistribute any of Anthropic's files.

<p align="center">
  <img src="docs/images/claude-desktop-fedora-dark.png" width="820" alt="Claude Desktop running on Fedora 44 GNOME in dark mode" />
</p>

## Install

```bash
sudo dnf install curl gnupg2 binutils tar
curl -fLO https://github.com/ajithakdev/claude-desktop-rpm/releases/latest/download/claude-desktop-rpm.sh
chmod +x claude-desktop-rpm.sh && ./claude-desktop-rpm.sh install
```

Open **Claude** from the app menu and sign in. Then check your setup:

```bash
claude-desktop-rpm doctor
```

```
Claude Desktop
  ok    installed: 3.6556.2
  ok    launcher (dark mode fix, staged updates)
  ok    auto-update on
  ok    GNOME search provider
Desktop
  ok    tray icon (AppIndicator extension on)
  ok    keyring (sign-in is saved)
  ok    Quick Entry hotkey (GlobalShortcuts portal)
Cowork
  ok    /dev/kvm
  ...
All good.
```

Want Cowork (Claude's agent mode that runs in a VM, paid plans only)? Run `claude-desktop-rpm cowork` in a terminal, then log out and back in.

## Features

- **Official and verified.** Downloads from `downloads.claude.ai` only. Checks Anthropic's key fingerprint, the signed index, its `Valid-Until` date and both checksums, and stops on any mismatch.
- **Updates itself.** A daily check installs new versions. If Claude is open, the update waits and goes in the next time you start Claude, with no download at launch.
- **Dark mode that follows GNOME.** Electron ignores GNOME's dark style, so the System theme stayed light. The launcher fixes that.
- **Cowork works.** Installs QEMU, edk2-ovmf and virtiofsd from Fedora's repos and sets up KVM access, the same steps Anthropic lists for Debian. It doesn't touch any packaged file.
- **GNOME search.** Your Claude sessions show up in the Activities search.
- **`doctor`** finds what's missing (tray extension, keyring, KVM group, portals) and tells you the exact fix.
- **No root for the app.** It lives in `~/.local`. Only the opt-in `cowork` command uses sudo, to install Fedora packages and set up KVM.
- **Clean uninstall.** `claude-desktop-rpm uninstall` removes everything it added and keeps your chats.

## Commands

| Command | What it does |
| --- | --- |
| `install`, `update` | Install the newest version. Does nothing if you're current. |
| `update --force` | Reinstall the current version. |
| `auto-update on`, `off` | Turn the daily update check on or off. No argument shows its state. |
| `doctor` | Check everything and print fixes. |
| `cowork` | Set up Cowork (uses sudo). |
| `version` | Print the installed version. |
| `uninstall` | Remove the app, launcher, timer and search provider. Chats and sign-in stay. |

## What it changes on your system

| | |
| --- | --- |
| Files | Only `~/.local` and `~/.config`. Every path is listed in the [guide](RESOURCES-AND-GUIDE.md#files-it-writes). `uninstall` removes them and rebuilds the menu, file-type and icon caches, so nothing still points at Claude. Your chats and sign-in in `~/.config/Claude` stay. |
| Network | The script only talks to `downloads.claude.ai`. The app itself talks to Anthropic's servers, as it does on every platform. |
| Root | `install`, `update` and `uninstall` never use sudo. `cowork` does, to install `qemu-system-x86-core`, `edk2-ovmf` and `virtiofsd` from Fedora's repos, write `/etc/modules-load.d/vhost_vsock.conf`, load `vhost_vsock` and add you to the `kvm` group. It never changes a file a package owns, so `rpm -V` stays clean. |
| Tested | `tests/sandbox.sh` checks all of this in a fresh Fedora 44 container on every pull request. |

## How it works

1. Fetch Anthropic's signing key and check its fingerprint (`31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`).
2. Verify that `InRelease` is signed by that exact key, and that it hasn't expired.
3. Check the `Packages` index against `InRelease`, and the `.deb` against `Packages`.
4. Unpack the `.deb` into `~/.local/lib/claude-desktop` in one atomic swap, and add a launcher, menu entry, icons and the `claude://` sign-in handler.
5. A systemd user timer repeats this daily. If Claude is open, the verified update is staged and the launcher puts it in place before the next start.

Every file it writes is listed in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

## Why this one

There are good projects in this space ([see below](#related-projects)). They make different trade-offs:

| | claude-desktop-rpm | Third-party dnf repos | Build-your-own RPM scripts |
| --- | --- | --- | --- |
| Who you trust | Anthropic only | Anthropic and the repo owner's key | Anthropic and the build script |
| App files | Unmodified | Some patch the app | Unmodified or patched |
| Needs root to install | No | Yes | Yes |
| Updates | Daily, automatic | With `dnf upgrade` | Re-run the build |
| Fedora fixes (dark mode, Cowork setup) | Yes | Varies | Varies |

Pick this one if you want Anthropic's exact build with no extra signing key in your system.

## FAQ

**Is this safe?**
It only installs what Anthropic signed, and it refuses anything that fails a check. Read the script; it's under 400 lines. See [SECURITY.md](SECURITY.md).

**Is this official?**
No. The app is Anthropic's official Linux build; the installer is a community project, not affiliated with Anthropic. Anthropic currently supports only Debian and Ubuntu, and [says other distributions are coming](https://code.claude.com/docs/en/desktop-linux).

**Why isn't it an `.rpm` file?**
An RPM would need root to install and a signing key you'd have to trust. Unpacking Anthropic's package into your home folder avoids both. The name says what it's for: RPM-based systems.

**The app says "Update available" and links to apt instructions.**
That's Anthropic's button. Updates arrive by themselves within a day; to update now, quit Claude and run `claude-desktop-rpm update`.

**The System theme is light even though GNOME is dark.**
Run `claude-desktop-rpm update --force` once to get the new launcher, then reopen Claude.

**Does it work on KDE, RHEL, Rocky or Alma?**
Probably, but only Fedora 44 GNOME on x86_64 is tested. Reports are welcome.

**Claude says "Hardware acceleration disabled" after a reboot.**
If Claude is still open when the computer shuts down, its graphics process can fail to restart and Claude counts that as a crash. Turn hardware acceleration back on from Claude's Help menu, then restart Claude. Quitting Claude from the tray before a reboot avoids it.

**What doesn't work?**
Computer Use and dictation, because Anthropic's Linux build doesn't have them yet on any distribution.

## Contributing

Bug reports, test reports from other desktops and distros, and fixes are all welcome. The project is one Bash script with an end-to-end test, so it's easy to get into:

```bash
git clone https://github.com/ajithakdev/claude-desktop-rpm && cd claude-desktop-rpm
shellcheck claude-desktop-rpm.sh tests/*.sh
tests/mock-repo.sh   # attack tests against a fake repository, offline
tests/e2e.sh         # installs into a temp folder, never touches your own install
tests/guidelines.sh  # Fedora packaging, licensing and writing rules, offline
tests/sandbox.sh     # fresh Fedora 44 container: install, uninstall, cowork (needs podman)
```

Start with [CONTRIBUTING](.github/CONTRIBUTING.md) and the [good first issues](https://github.com/ajithakdev/claude-desktop-rpm/labels/good%20first%20issue). Questions go to [Discussions](https://github.com/ajithakdev/claude-desktop-rpm/discussions).

<a href="https://github.com/ajithakdev/claude-desktop-rpm/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=ajithakdev/claude-desktop-rpm" alt="Contributors" />
</a>

## Related projects

- [aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian): repackages Claude Desktop for many distros, with APT and DNF repositories.
- [dewzor/claude-desktop-fedora](https://github.com/dewzor/claude-desktop-fedora): builds a native RPM from the official package, with Copr auto-updates.
- [k3d3/claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake): Nix flake.

## Star history

<a href="https://star-history.com/#ajithakdev/claude-desktop-rpm&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=ajithakdev/claude-desktop-rpm&type=Date&theme=dark" />
    <img alt="Star history" src="https://api.star-history.com/svg?repos=ajithakdev/claude-desktop-rpm&type=Date" />
  </picture>
</a>

## Credits

Maintained by [ajithakdev](https://github.com/ajithakdev). Written with help from Claude, Anthropic's AI assistant, which drafted much of the script, tests and docs; every change is reviewed and tested before release. Thanks to Marko Jokinen for the signature-check report in [#7](https://github.com/ajithakdev/claude-desktop-rpm/issues/7), and to Fedora Magazine editors Gregory Lee Bartholomew, Richard England and Justin Wheeler, whose [review](https://discussion.fedoraproject.org/t/205949) led to [#8](https://github.com/ajithakdev/claude-desktop-rpm/issues/8) and [#9](https://github.com/ajithakdev/claude-desktop-rpm/issues/9).

## License

MIT for the script. Claude Desktop is Anthropic's software under [Anthropic's terms](https://www.anthropic.com/legal/consumer-terms). Not affiliated with or endorsed by Anthropic.
