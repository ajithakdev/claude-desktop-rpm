# claude-desktop-rpm

Every link and how-to is in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

- One Bash script, `claude-desktop-rpm.sh`. CI runs ShellCheck and `tests/e2e.sh` (real install into a temp prefix via `CLAUDE_DESKTOP_PREFIX`).
- Never patch Anthropic's app files; fixes go in the generated launcher (`write_launcher`), desktop entry or system setup.
- Extend `tests/e2e.sh` and `docs/TESTING.md` with every new command.
- Never weaken the four verification checks; see SECURITY.md.
- Add a CHANGELOG line under Unreleased with every user-visible change. Release: tag `vX.Y.Z`, then `gh release create` with that version's notes and the script attached.
