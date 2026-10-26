# Testing checklist

Run the automated test first, then the manual checks that need a real desktop. Tick every box before tagging a release.

## Automated

```bash
shellcheck claude-desktop-rpm.sh tests/*.sh
tests/mock-repo.sh
tests/e2e.sh
tests/guidelines.sh
tests/sandbox.sh   # needs podman; SKIP_COWORK=1 skips the QEMU download
```

`tests/guidelines.sh` reads the repo and checks it against Fedora's rules: the [Fedora Magazine writing guidelines](https://docs.fedoraproject.org/en-US/fedora-magazine/writing-guidelines/), the [AI-Assisted Contributions Policy](https://docs.fedoraproject.org/en-US/council/policy/ai-contribution-policy/) and what the Magazine editors asked for in the [article proposal](https://discussion.fedoraproject.org/t/205949). It checks that:

- [ ] no `sudo` command writes under `/usr`, there are no third-party repos (Copr included), no `rpm -i` from a URL and no `curl | sh`
- [ ] every `sudo dnf` call installs or reinstalls Fedora packages, and only `cowork` runs sudo
- [ ] the script refuses root and only contacts `downloads.claude.ai`
- [ ] the license is MIT with an SPDX header; the README says Claude Desktop is proprietary, which plan each feature needs, links Anthropic's terms, says it isn't affiliated and discloses AI help
- [ ] the docs have no em or en dashes, no exclusionary terms, US spelling, third-party names styled as their owners do, and sentence-case headings
- [ ] every relative link and README anchor resolves, CHANGELOG has an Unreleased section, and the README covers every command and needed package

`tests/sandbox.sh` starts a fresh Fedora 44 container and works as a normal user with no sudo rights. It checks that:

- [ ] the README's `dnf` line is enough to install, and install needs no sudo
- [ ] `version` and `doctor` run
- [ ] every file written is in a location RESOURCES-AND-GUIDE.md lists
- [ ] `uninstall` leaves only the regenerated desktop caches, and none of them still mention Claude
- [ ] `cowork` installs only packages from Fedora's repos, leaves `rpm -V edk2-ovmf` clean, writes the `vhost_vsock` file and adds the `kvm` group
- [ ] `cowork` restores `edk2-ovmf`'s links when an older release replaced them

`tests/mock-repo.sh` serves a fake repository on 127.0.0.1 and runs full installs into temporary folders. It checks that each of these is refused: a signature from a second key in `key.asc`, a `key.asc` without Anthropic's key, a bad signature, an expired index, a missing `Valid-Until`, a tampered `Packages`, a tampered `.deb`, an odd package path, and an older version. It also checks that a clean fake repository installs.

`tests/e2e.sh` downloads the real package from Anthropic and installs it into a temporary folder, so it never touches `~/.local`. It checks:

- [ ] the signing key, `InRelease` signature and both checksums pass (any failure stops the install)
- [ ] Anthropic's real index is accepted; an index signed by a second key in `key.asc`, or by an expired pinned key, is refused; unsigned text after the signature is dropped
- [ ] `update` refuses to install an older version
- [ ] the app, version file, launcher, menu entry, `claude://` handler, icons, search provider and the script's own copy are in place
- [ ] `update` does nothing when the version is current
- [ ] `version` prints the installed version
- [ ] the launcher sets `GTK_THEME=Adwaita:dark` when GNOME's style is dark, leaves it unset when light, and keeps a `GTK_THEME` you set yourself
- [ ] with Claude open, `update` refuses, `update --auto` stages the new version without touching the app, and does not download it twice
- [ ] `apply-staged` waits while Claude is open, then installs the staged version and clears the stage
- [ ] `doctor` runs
- [ ] `uninstall` removes the app, launcher, script copy, menu entry and search provider

CI runs the same script on every push and every Monday.

## Manual (on Fedora with a desktop)

- [ ] `./claude-desktop-rpm.sh install` finishes, and Claude shows up in the app menu
- [ ] Sign-in in the browser comes back to the app (tests the `claude://` handler)
- [ ] Settings > Appearance > System: dark when GNOME's style is Dark, light when Light (quit and reopen Claude after switching)
- [ ] Light and Dark buttons still work
- [ ] `claude-desktop-rpm doctor` shows no warnings you didn't expect
- [ ] `systemctl --user list-timers claude-desktop-rpm-update.timer` shows the next run; `auto-update off` removes it and `auto-update on` brings it back
- [ ] Run `systemctl --user start claude-desktop-rpm-update.service` with an older version installed and Claude open: a notification says the update is ready, and reopening Claude starts the new version
- [ ] GNOME Activities search for a Claude session title shows it, and clicking it opens the session
- [ ] Quit Claude, run `update`: says up to date, or installs the new version
- [ ] `update` while Claude is running stops with "quit it first"
- [ ] `cowork`, log out and in, then a Cowork task starts
- [ ] after `cowork`, `rpm -V edk2-ovmf` prints nothing and `doctor` shows no firmware warning
- [ ] `uninstall` removes the menu entry; `~/.config/Claude` is still there
- [ ] after `uninstall`, a `.mcpb` file no longer opens with Claude
