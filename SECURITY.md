# Security policy

## What the script trusts

The script downloads Claude Desktop only from Anthropic's own repository at `downloads.claude.ai` and refuses to install unless every check passes:

1. Anthropic's signing key has the fingerprint `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`, the one Anthropic publishes in its [Linux install docs](https://code.claude.com/docs/en/desktop-linux).
2. The repository's `InRelease` file has a good signature from that key or one of its subkeys (gpg's `VALIDSIG` must name it as the primary key), not just from any key that came in `key.asc`. A signature from an expired or revoked key is refused.
3. `InRelease` has a `Valid-Until` date and is not past it, so an old signed index can only be replayed while it is still valid. Within that window the script also refuses to install a version older than the one you have (`update --force` overrides).
4. The `Packages` index matches the checksum in `InRelease`.
5. The `.deb` matches the checksum in `Packages`.

Automatic updates run the same checks. An update downloaded while Claude is open is verified before it is staged, and staged updates live in your own `~/.local`, so only your user can change them.

The app installs into your home directory and runs without root; the script refuses to run as root. Only `cowork` uses sudo: it installs QEMU, edk2-ovmf and virtiofsd with dnf, writes `/etc/modules-load.d/vhost_vsock.conf`, loads `vhost_vsock` and adds you to the `kvm` group. It is opt-in and never runs on its own.

The daily update timer installs new versions without asking, after the same checks. Turn it off with `claude-desktop-rpm auto-update off`.

## Supported versions

Only the latest release gets fixes.

## Reporting a vulnerability

Don't open a public issue. Use [private vulnerability reporting](https://github.com/ajithakdev/claude-desktop-rpm/security/advisories/new) on this repo.

Problems in Claude Desktop itself go to Anthropic: https://www.anthropic.com/responsible-disclosure-policy
