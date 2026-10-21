# claude-desktop-fedora: resources and guide

Every link for the Claude Desktop Fedora installer, what it is for, and how to run it. Passwords and keys are never written here.

## TL;DR

- Bash installer and updater for Anthropic's Claude Desktop Linux beta on Fedora.
- Downloads the official Debian package from Anthropic and verifies its signature and checksums.
- Installs the app into `~/.local` so it runs without root privileges.
- Includes setup for the Cowork virtual machine environment on Fedora.
- Preserves user configuration and chats in `~/.config/Claude` when uninstalled.

## Links and what each one is for

### Public

| Link | Use it for |
| --- | --- |
| https://github.com/ajithakdev/claude-desktop-fedora | Source code and installation instructions |

### Behind the scenes

| Link | Use it for |
| --- | --- |
| https://downloads.claude.ai/claude-desktop/apt/stable | Anthropic package repository for Claude Desktop |
| https://downloads.claude.ai/claude-desktop/key.asc | Anthropic package signing key |

## Accounts

| Service | Account | Role |
| --- | --- | --- |
| GitHub | `ajithakdev` | Owner |

## Run and release

| Job | How |
| --- | --- |
| Install dependencies | `sudo dnf install curl gnupg2 binutils tar` |
| Install | `./claude-desktop-fedora.sh install` |
| Update | Quit Claude Desktop, then run `./claude-desktop-fedora.sh update` |
| Force reinstall | `./claude-desktop-fedora.sh update --force` |
| Set up Cowork | `./claude-desktop-fedora.sh cowork`, then log out and back in |
| Check version | `./claude-desktop-fedora.sh version` |
| Uninstall | `./claude-desktop-fedora.sh uninstall` |

## When something goes wrong

| Problem | Fix |
| --- | --- |
| Missing required tools | Run `sudo dnf install curl gnupg2 binutils tar coreutils` |
| App running during install or update | Quit Claude Desktop from tray icon, then rerun the command |
| `/dev/kvm` missing during Cowork setup | Enable SVM or VT-x virtualization in your BIOS |
| Cowork fails after setup | Log out and back in to apply the `kvm` group membership |
| Package verification fails | The script halts if the Anthropic signing key or checksums do not match |

## More detail

- `claude-desktop-fedora.sh`: installer script and Cowork setup
- `README.md`: usage guide, verification steps, and limits
- `LICENSE`: MIT license terms
