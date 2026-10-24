# claude-desktop-rpm

Every link and how-to is in [RESOURCES-AND-GUIDE.md](RESOURCES-AND-GUIDE.md).

- One Bash script, `claude-desktop-rpm.sh`. CI runs `bash -n` and ShellCheck.
- Never weaken the four verification checks; see SECURITY.md.
- Add a CHANGELOG line under Unreleased with every user-visible change. Release: tag `vX.Y.Z`, then `gh release create` with that version's notes and the script attached.
