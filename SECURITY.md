# Security policy

## What the script trusts

The script downloads Claude Desktop only from Anthropic's own repository at `downloads.claude.ai` and refuses to install unless every check passes:

1. Anthropic's signing key has the fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.
2. The repository's `InRelease` file is signed by that key.
3. `InRelease` is not past its `Valid-Until` date, so an old signed index can't be replayed.
4. The `Packages` index matches the checksum in `InRelease`.
5. The `.deb` matches the checksum in `Packages`.

Automatic updates run the same checks. An update downloaded while Claude is open is verified before it is staged, and staged updates live in your own `~/.local`, so only your user can change them.

The app installs into your home directory and runs without root; the script refuses to run as root. Only `cowork` uses sudo, to install Fedora packages and set up KVM.

## Supported versions

Only the latest release gets fixes.

## Reporting a vulnerability

Don't open a public issue. Use [private vulnerability reporting](https://github.com/ajithakdev/claude-desktop-rpm/security/advisories/new) on this repo.

Problems in Claude Desktop itself go to Anthropic: https://www.anthropic.com/responsible-disclosure-policy
