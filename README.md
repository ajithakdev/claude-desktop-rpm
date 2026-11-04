<div align="center">

<img src="docs/images/icon.png" width="88" alt="" />

# claude-desktop-rpm

**Anthropic's official Claude Desktop on Fedora: verified, unmodified, and kept up to date.**

[![CI](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml/badge.svg)](https://github.com/ajithakdev/claude-desktop-rpm/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/ajithakdev/claude-desktop-rpm)](https://github.com/ajithakdev/claude-desktop-rpm/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ajithakdev/claude-desktop-rpm/total?label=downloads)](https://github.com/ajithakdev/claude-desktop-rpm/releases)
[![Fedora 44](https://img.shields.io/badge/Fedora-44-51A2DA?logo=fedora&logoColor=white)](https://fedoraproject.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Follow @ajithakdev](https://img.shields.io/github/followers/ajithakdev?label=Follow%20%40ajithakdev&style=social)](https://github.com/ajithakdev)

[Install](#install) · [Commands](#commands) · [What it changes](#what-it-changes-on-your-system) · [Why this one](#why-this-one) · [FAQ](#faq) · [Guide](RESOURCES-AND-GUIDE.md)

</div>

Anthropic ships Claude Desktop for Linux only as a `.deb` for Ubuntu and Debian. This Bash script downloads that package from Anthropic, checks its signature and checksums, and installs it into your home folder without root. It also fixes what breaks on Fedora out of the box: dark mode, Cowork, the tray icon, GNOME search and updates.

Claude Desktop is Anthropic's proprietary app. Chat works on every plan, including Free; Claude Code and Cowork need a paid plan (Pro, Max, Team or Enterprise). Details are in Anthropic's [download FAQ](https://claude.com/download) and [plan table](https://support.claude.com/en/articles/10065433-install-claude-desktop). This script is MIT licensed, isn't made by Anthropic, and doesn't redistribute any of its files.

<p align="center">
  <img src="docs/images/terminal.svg" width="660" alt="Terminal on Fedora 44: claude-desktop-rpm installs Claude Desktop 3.6556.2 into ~/.local, then doctor reports every check ok and All good" />
</p>

## Install

```bash
sudo dnf install curl gnupg2 binutils tar
curl -fLO https://github.com/ajithakdev/claude-desktop-rpm/releases/latest/download/claude-desktop-rpm.sh
chmod +x claude-desktop-rpm.sh && ./claude-desktop-rpm.sh install
```

Open **Claude** from the app menu and sign in. If anything looks off, `claude-desktop-rpm doctor` checks the setup and prints the fix. For Cowork, run `claude-desktop-rpm cowork` once, then log out and back in.

<details>
<summary>Screenshot</summary>

<p align="center"><img src="docs/images/claude-desktop-fedora-dark.png" width="820" alt="Claude Desktop running on Fedora 44 GNOME in dark mode" /></p>

</details>

## Commands

| Command | What it does |
| --- | --- |
| `install`, `update` | Install the newest version. Does nothing if you're current. |
| `update --force` | Reinstall the current version. |
| `auto-update on`, `off` | Turn the daily update check on or off. No argument shows its state. |
| `doctor` | Check everything and print fixes. |
| `cowork` | Set up Cowork (uses sudo). |
| `version` | Print the installed version. |
| `uninstall` | Remove everything it added. Chats and sign-in stay. |

## What it changes on your system

| Area | What happens |
| --- | --- |
| Files | Only `~/.local` and `~/.config`; every path is in the [guide](RESOURCES-AND-GUIDE.md#files-it-writes). `uninstall` removes them and rebuilds the menu, file-type and icon caches. Your chats and sign-in in `~/.config/Claude` stay. |
| Network | The script only talks to `downloads.claude.ai`. The app itself talks to Anthropic's servers, as on every platform. |
| Root | `install`, `update` and `uninstall` never use sudo. `cowork` does, to install `qemu-system-x86-core`, `edk2-ovmf` and `virtiofsd` from Fedora's repos, write `/etc/modules-load.d/vhost_vsock.conf`, load `vhost_vsock` and add you to the `kvm` group. It never changes a file a package owns, so `rpm -V` stays clean. |
| Updates | A systemd user timer checks once a day. If Claude is open, the verified update waits and goes in the next time you start it. `auto-update off` stops it. |
| Tested | `tests/sandbox.sh` checks all of this in a fresh Fedora 44 container on every pull request. People have also run it on KDE Plasma and on Fedora Atomic ([#2](https://github.com/ajithakdev/claude-desktop-rpm/issues/2)). |

## Why this one

Before installing anything, the script checks Anthropic's key fingerprint, that the repository index is signed by that key and hasn't expired, and the checksums of the package list and the `.deb`. It stops on any mismatch ([SECURITY.md](SECURITY.md) has the details).

| | claude-desktop-rpm | Third-party dnf repos | Build-your-own RPM scripts |
| --- | --- | --- | --- |
| Who you trust | Anthropic only | Anthropic and the repo owner's key | Anthropic and the build script |
| App files | Unmodified | Some patch the app | Unmodified or patched |
| Needs root to install | No | Yes | Yes |
| Updates | Daily, automatic | With `dnf upgrade` | Re-run the build |

Pick this one if you want Anthropic's exact build with no extra signing key on your system. Other good options: [claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian) (APT and DNF repos), [claude-desktop-fedora](https://github.com/dewzor/claude-desktop-fedora) (native RPM with Copr updates) and [claude-desktop-linux-flake](https://github.com/k3d3/claude-desktop-linux-flake) (Nix).

## FAQ

**Is this official?**
No. The app is Anthropic's official Linux build; the installer is a community project, not affiliated with Anthropic. Anthropic supports only Debian and Ubuntu for now and [says other distributions are coming](https://code.claude.com/docs/en/desktop-linux).

**Why isn't it an `.rpm` file?**
An RPM would need root to install and a signing key you'd have to trust. Unpacking Anthropic's package into your home folder avoids both. The name says what it's for: RPM-based systems.

**What doesn't work?**
Computer Use, which Anthropic's Linux build doesn't have yet on any distribution. Dictation works (tested in 3.6556.2, chat and Code tabs). Tested on Fedora 44 GNOME (x86_64) and reported working on KDE Plasma 6.7 (Aurora 44, Wayland) in [#2](https://github.com/ajithakdev/claude-desktop-rpm/issues/2). RHEL, Rocky and Alma probably work, and reports are welcome.

**Something looks wrong.**
Run `claude-desktop-rpm doctor`. The [guide](RESOURCES-AND-GUIDE.md#when-something-goes-wrong) covers the rest, such as the app's "Update available" button, a light System theme, or "Hardware acceleration disabled" after a reboot.

## Contributing

Bug reports, test reports from other desktops and fixes are welcome. [CONTRIBUTING](.github/CONTRIBUTING.md) has the setup and the four test scripts, and there are [good first issues](https://github.com/ajithakdev/claude-desktop-rpm/labels/good%20first%20issue). Questions go to [Discussions](https://github.com/ajithakdev/claude-desktop-rpm/discussions).

## Releases and downloads

<a href="https://github.com/ajithakdev/claude-desktop-rpm/releases/latest">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/release-dark.svg" />
    <img alt="Latest release: version, date, the newest Claude Desktop in Anthropic's repository, desktops it was tested on and the checks it runs" src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/release-light.svg" width="660" />
  </picture>
</a>

<a href="https://github.com/ajithakdev/claude-desktop-rpm/releases">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/stats-dark.svg" />
    <img alt="Stars over time and script downloads per release" src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/stats-light.svg" width="660" />
  </picture>
</a>

Downloads count the script itself, per release; GitHub doesn't keep a daily history. Updates come from Anthropic's repository, not this script, so this is close to the number of installs. Both cards are redrawn daily.

## Credits

Maintained by [ajithakdev](https://github.com/ajithakdev). Written with help from Claude, Anthropic's AI assistant, which drafted much of the script, tests and docs; every change is reviewed and tested before release.

These people found bugs, tested on other desktops or reviewed the project, and it is better for it. Fedora names link to their [Fedora Discussion](https://discussion.fedoraproject.org) profiles, where the [article review](https://discussion.fedoraproject.org/t/205949) and the [script thread](https://discussion.fedoraproject.org/t/205947) happened.

<table>
  <tr>
    <td align="center" valign="top" width="150"><a href="https://github.com/aurora"><img src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/avatar-aurora.svg" width="72" height="72" alt="Harald Lapp" /></a><br /><a href="https://github.com/aurora"><sub><b>Harald Lapp</b></sub></a><br /><sub>KDE Plasma test <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/2">#2</a></sub></td>
    <td align="center" valign="top" width="150"><a href="https://discussion.fedoraproject.org/u/thephatlee"><img src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/avatar-thephatlee.svg" width="72" height="72" alt="Marko Jokinen" /></a><br /><a href="https://discussion.fedoraproject.org/u/thephatlee"><sub><b>Marko Jokinen</b></sub></a><br /><sub>Signature check <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/7">#7</a></sub></td>
    <td align="center" valign="top" width="150"><a href="https://discussion.fedoraproject.org/u/glb"><img src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/avatar-glb.svg" width="72" height="72" alt="Gregory Lee Bartholomew" /></a><br /><a href="https://discussion.fedoraproject.org/u/glb"><sub><b>Gregory Lee Bartholomew</b></sub></a><br /><sub>Magazine review <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/8">#8</a> <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/9">#9</a></sub></td>
    <td align="center" valign="top" width="150"><a href="https://discussion.fedoraproject.org/u/rlengland"><img src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/avatar-rlengland.svg" width="72" height="72" alt="Richard England" /></a><br /><a href="https://discussion.fedoraproject.org/u/rlengland"><sub><b>Richard England</b></sub></a><br /><sub>Magazine review <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/8">#8</a> <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/9">#9</a></sub></td>
    <td align="center" valign="top" width="150"><a href="https://discussion.fedoraproject.org/u/jflory7"><img src="https://raw.githubusercontent.com/ajithakdev/claude-desktop-rpm/stats/avatar-jflory7.svg" width="72" height="72" alt="Justin Wheeler" /></a><br /><a href="https://discussion.fedoraproject.org/u/jflory7"><sub><b>Justin Wheeler</b></sub></a><br /><sub>Magazine review <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/8">#8</a> <a href="https://github.com/ajithakdev/claude-desktop-rpm/issues/9">#9</a></sub></td>
  </tr>
</table>

Thanks also to the free services this project runs on: [GitHub](https://github.com) for hosting, CI and releases, [Shields.io](https://shields.io) for the badges, and [Fedora Discussion](https://discussion.fedoraproject.org) for the place to ask.

## More from me

| Project | What it is |
| --- | --- |
| [Toolglass](https://toolglass.ajithakdev.com) ([repo](https://github.com/ajithakdev/toolglass)) | 41 free tools that run in your browser: image compressor, screen recorder, JSON, JWT, regex and more. Works offline, no tracking. |
| [MeterX](https://meterx.ajithakdev.com) ([repo](https://github.com/ajithakdev/meterx)) | A speed test in your browser toolbar: download, upload, ping, jitter and packet loss. |
| [Minnoli](https://minnoli.ajithakdev.com) | All the Tamil Nadu electricity bills you look after on one screen, sorted by due date, in Tamil and English. |
| [amazon-pincode-checker](https://github.com/ajithakdev/amazon-pincode-checker) | Checks whether an Amazon.in product delivers to a list of Indian pincodes. |
| [clip-paste](https://github.com/ajithakdev/clip-paste) | A clipboard manager for the COSMIC desktop that pastes straight into your window. |
| [CNoBS](https://github.com/ajithakdev/CNoBS) | Learn C in 20-minute chunks: see the output, guess, then break it. |

More at [ajithakdev.com](https://ajithakdev.com).

## Support

The script is free and stays free. If it saved you an evening, a star, a follow on [GitHub](https://github.com/ajithakdev) or a test report from your desktop helps a lot. If you'd like to send a small thank-you:

<table>
  <tr>
    <td align="center" valign="top" width="280"><b>From anywhere</b><br /><br /><a href="https://ko-fi.com/ajithakdev"><img src="https://ko-fi.com/img/githubbutton_sm.svg" alt="Support me on Ko-fi" /></a><br /><br /><sub>Card or PayPal on <a href="https://ko-fi.com/ajithakdev">ko-fi.com/ajithakdev</a></sub></td>
    <td align="center" valign="top" width="280"><b>In India, over UPI</b><br /><br /><img src="docs/images/upi-qr.svg" width="120" height="120" alt="UPI QR code for ajithakdev@sbi" /><br /><code>ajithakdev@sbi</code><br /><sub>Scan or paste into GPay, PhonePe or any UPI app</sub></td>
  </tr>
</table>

## License

MIT for the script. Claude Desktop is Anthropic's software under [Anthropic's terms](https://www.anthropic.com/legal/consumer-terms). Not affiliated with or endorsed by Anthropic.
