# Contributing

The whole project is one Bash script, `claude-desktop-rpm.sh`. Keep it that way: no extra dependencies beyond what Fedora ships, and nothing from Anthropic committed to the repo.

## Before you open a PR

```bash
sudo dnf install ShellCheck
shellcheck claude-desktop-rpm.sh
./claude-desktop-rpm.sh update --force   # reinstall to check your change
./claude-desktop-rpm.sh uninstall && ./claude-desktop-rpm.sh install
```

CI runs `bash -n` and ShellCheck on every push and PR.

## Rules

- Never weaken the verification steps (key fingerprint, `InRelease` signature, both checksums). A PR that skips one will be closed.
- The app installs to `~/.local` without sudo. Only `cowork` may use sudo.
- Add a line to `CHANGELOG.md` under `## [Unreleased]`.
- Commit messages start with `feat:`, `fix:`, `docs:`, `ci:` or `chore:`.
