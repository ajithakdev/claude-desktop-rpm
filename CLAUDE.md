# claude-desktop-rpm

Every link and how-to is in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

- One Bash script, `claude-desktop-rpm.sh`. CI runs ShellCheck, `tests/mock-repo.sh` (offline attack tests against a fake repo) and `tests/e2e.sh` (real install into a temp prefix via `CLAUDE_DESKTOP_PREFIX`).
- Never patch Anthropic's app files; fixes go in the generated launcher (`write_launcher`), desktop entry or system setup.
- Extend `tests/e2e.sh` and `docs/TESTING.md` with every new command.
- Never weaken the verification checks; see SECURITY.md. Every new check gets a tampered case in `tests/mock-repo.sh`.
- Add a CHANGELOG line under Unreleased with every user-visible change. Release: commit `chore: release vX.Y.Z` on main and push the tag; `.github/workflows/release.yml` tests and publishes (script + SHA256SUMS + CHANGELOG notes). Don't run `gh release create` by hand.
- Attribution lives only in the README Credits section; keep it out of commits, PRs and code.
