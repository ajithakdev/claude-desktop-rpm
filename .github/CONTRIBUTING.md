# Contributing

The whole project is one Bash script, `claude-desktop-rpm.sh`. Keep it that way: no extra dependencies beyond what Fedora ships, and nothing from Anthropic committed to the repo.

## Before you open a PR

```bash
sudo dnf install ShellCheck
shellcheck claude-desktop-rpm.sh tests/e2e.sh
tests/e2e.sh                              # real install into a temp folder
./claude-desktop-rpm.sh update --force    # then try it on your own install
```

CI runs ShellCheck and `tests/e2e.sh` on every push and PR. Before a release, go through [docs/TESTING.md](../docs/TESTING.md).

## Rules

- Never weaken the verification steps (key fingerprint, `InRelease` signature, both checksums). A PR that skips one will be closed.
- The app installs to `~/.local` without sudo. Only `cowork` may use sudo.
- Never patch files inside Anthropic's app. Fixes go in the launcher, the desktop entry, or system setup.
- Add a line to `CHANGELOG.md` under `## [Unreleased]`.
- Commit messages start with `feat:`, `fix:`, `docs:`, `ci:` or `chore:`.
