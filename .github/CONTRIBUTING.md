# Contributing

The whole project is one Bash script, `claude-desktop-rpm.sh`. Keep it that way: no extra dependencies beyond what Fedora ships, and nothing from Anthropic committed to the repo.

## Before you open a PR

```bash
sudo dnf install ShellCheck
shellcheck claude-desktop-rpm.sh tests/*.sh
tests/mock-repo.sh                        # attack tests against a fake repo, offline, 2 seconds
tests/e2e.sh                              # real install into a temp folder
tests/guidelines.sh                       # Fedora packaging, licensing and writing rules, offline
tests/sandbox.sh                          # fresh Fedora 44 container (needs podman)
./claude-desktop-rpm.sh update --force    # then try it on your own install
```

CI runs ShellCheck and all four test scripts on every push and PR. [docs/REVIEW.md](../docs/REVIEW.md) lists what a review checks, so you can check it yourself first. Before a release, go through [docs/TESTING.md](../docs/TESTING.md).

## Rules

- Never weaken the verification steps (key fingerprint, `InRelease` signed by that key, `Valid-Until`, no downgrade, both checksums). A PR that skips one will be closed. A new check gets a tampered case in `tests/mock-repo.sh`.
- The app installs to `~/.local` without sudo. Only `cowork` (to install packages and set up KVM) and `links` may use sudo. Never write or link anything under `/usr`; the distribution's packages own it. The two exceptions are named line by line in `tests/guidelines.sh`: `links` writes `/usr/local/bin/xdg-open`, and `cowork` on openSUSE links the firmware into `/usr/share/OVMF`, which openSUSE's firmware package doesn't use.
- Never patch files inside Anthropic's app. Fixes go in the launcher, the desktop entry, or system setup.
- Add a line to `CHANGELOG.md` under `## [Unreleased]`.
- Commit messages start with `feat:`, `fix:`, `docs:`, `ci:` or `chore:`.
