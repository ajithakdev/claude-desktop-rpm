# Reviewing a pull request

How a PR to claude-desktop-rpm gets reviewed before it is merged. It is based on FlatPark's [review runbook](https://github.com/flatpark/flatpark/blob/main/docs/reviewers/review-runbook.md) and cut down to fit one Bash script that thousands of people run with sudo.

- **PRs from outside contributors** get the whole thing: the check table, then the Pre-merge checklist.
- **Our own PRs** get only the Pre-merge checklist. The PR description and CI are the record.
- **Dependabot and CI-only PRs** need nothing beyond green CI.

The output is one PR comment. Anything checked but left out of it reads as unchecked, so it carries the table with evidence, what was read, how to reproduce it and what was not covered. The reviewer recommends a verdict. Only the maintainer merges.

## Rule of engagement

Don't run a contributor's code on your own machine until you have read every line of it. Read first, then run it in `tests/sandbox.sh` (a throwaway Fedora container) or a VM. Never run it with your real sudo before that. If a decision really needs the code to run, run it in the sandbox and say so in the report.

## Phases

### 1. Scope

List every file the PR touches and mark the high-scrutiny ones:

- anything that runs under `sudo` (`cowork`, `links`) or writes outside `~/.local`
- the verification chain: key fingerprint, `InRelease` signature, `Valid-Until`, the `Packages` and `.deb` checksums, `self-update`
- `.github/` (workflows, CODEOWNERS, dependabot), `tests/` and `SECURITY.md`
- the generated launcher (`write_launcher`), the desktop entry and the systemd units, since they run on every launch

A PR that touches none of these is low risk. Say so and keep the review short.

### 2. Provenance

- Who sent it: account age, other work, whether an issue was discussed first.
- Commits: one author, an email that matches the account, no surprise co-authors.
- Was it asked for? A drive-by change to the verification code with no issue is a red flag on its own.

### 3. Static read

Read every changed line. For each file, write a few lines on what it does in the "What was read" section of the report. Check:

- every new external command, URL and download. New network access must go to `downloads.claude.ai` or this repo's releases.
- quoting, `set -euo pipefail` paths, and what happens when a command fails halfway
- that Fedora's path is unchanged unless the PR is meant to change it
- no em or en dashes, the repo's writing rules (`tests/guidelines.sh` checks most of them)

### 4. Tests

- A new command or behaviour adds a check to `tests/e2e.sh` and a line to `docs/TESTING.md`.
- A new verification check adds a tampered case to `tests/mock-repo.sh`.
- CI is green on the **final** head commit, not an earlier one.

### 5. Fedora regression proof

Thousands of people run this on Fedora, so a green CI is not enough. On a Fedora host:

- diff the `doctor` output of main and of the PR
- run `cowork` with sudo stubbed (a `PATH` shim that echoes) on main and on the PR, and diff the commands
- run `tests/sandbox.sh` on the PR head
- check distro detection for Fedora derivatives (Bazzite, Aurora, Bluefin, Nobara, Ultramarine) and for a missing `/etc/os-release`

### 6. End to end

Install, launch, `doctor`, `update`, `uninstall` on the system the PR is for, in a VM or on real hardware. The contributor's own report counts as evidence but does not replace this.

## Hard fails

Any one of these blocks the merge, whatever else the PR does:

- weakens, skips or makes optional any check listed in [SECURITY.md](../SECURITY.md)
- adds a download from anywhere other than `downloads.claude.ai` or this repo's GitHub releases
- adds sudo use outside `cowork` and `links`, or makes either one run on its own
- patches Anthropic's app files instead of the launcher, desktop entry or system setup
- touches `.github/` or `tests/` in a way that hides a failure (deleted checks, `|| true`, `continue-on-error`)
- adds a verification check with no tampered case in `tests/mock-repo.sh`
- obfuscated code, encoded blobs, or anything that writes persistence (cron, profile files, units) not described in the PR

## Verdict

- **PASS**: no hard fails, every row checked, CI green on the final head, end-to-end test done.
- **NEEDS-HUMAN**: a judgment call is left (a new permission, an untested distro, a design choice). Say exactly what.
- **REJECT**: a hard fail. Name it, and explain how the PR could be changed to pass.

For outside contributors, every finding is a blocker until it is fixed or shown to be harmless by an experiment. Keep the tone thankful; the bar stays where it is.

## Report template

Copy this into the PR comment and fill one row at a time.

````markdown
## Review: #N, <title>

Reviewed at `<sha>` against docs/REVIEW.md.

**Verdict: PASS / NEEDS-HUMAN / REJECT.** <one or two sentences>

### Checks

Legend: ✅ pass · ❌ fail · ⚠️ warn · 👤 needs-human · ➖ n/a

| # | Phase | Check | Verdict | Evidence |
|---|---|---|---|---|
| 1.1 | Scope | Files touched | | |
| 1.2 | Scope | High-scrutiny surface (sudo, verification, CI, launcher) | | |
| 2.1 | Provenance | Submitter and prior discussion | | |
| 2.2 | Provenance | Commit identity | | |
| 3.1 | Static | New commands, URLs, downloads | | |
| 3.2 | Static | Failure paths and quoting | | |
| 3.3 | Static | Fedora path unchanged | | |
| 4.1 | Tests | e2e and TESTING.md updated | | |
| 4.2 | Tests | mock-repo tampered case (if a check was added) | | |
| 4.3 | Tests | CI green on final head | | |
| 5.1 | Fedora | doctor diff, main vs PR | | |
| 5.2 | Fedora | cowork with sudo stubbed, diff | | |
| 5.3 | Fedora | sandbox.sh on PR head | | |
| 6.1 | E2E | Real install on the target system | | |
| 7.1 | Verdict | Hard fails | | |

### What was read, file by file

- **`file`**: what it does, anything odd.

### Findings

1. ...

### Reproduce

```sh
gh pr checkout N
...
```

### Not covered

- ...

## Pre-merge checklist

**Addressed**
- [x] ...

**Tested**
- [x] ...

**CI and release**
- [x] ...

**Docs**
- [x] CHANGELOG line under Unreleased

**Open**
- [ ] ...

**After merge:** ...
````
