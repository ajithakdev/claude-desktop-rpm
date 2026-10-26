#!/usr/bin/env bash
# Sandbox test: a fresh Fedora container, a normal user, the real package from Anthropic.
# Proves the README's dnf line is enough, install needs no root, every file it writes is
# listed in RESOURCES-AND-GUIDE.md, uninstall leaves the home folder as it found it, and
# cowork changes nothing rpm owns. Needs podman and network. SKIP_COWORK=1 skips the
# cowork part (it downloads QEMU).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE=${SANDBOX_IMAGE:-registry.fedoraproject.org/fedora:44}
command -v podman >/dev/null || { echo "SKIP: podman not installed"; exit 0; }

# The container runs this as root; everything the user does goes through `as_user`.
# shellcheck disable=SC2016 # expanded inside the container
podman run --rm --network=host -e SKIP_COWORK="${SKIP_COWORK:-}" -v "$ROOT:/src:ro,Z" "$IMAGE" bash -c '
set -euo pipefail
pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
check() { local what=$1; shift; if "$@"; then echo "  ok: $what"; pass=$((pass + 1)); else fail "$what"; fi; }

echo "== fresh Fedora: README packages only"
# Test harness only. Every Fedora Workstation has these.
dnf -y -q install shadow-utils findutils procps-ng util-linux shared-mime-info desktop-file-utils gtk-update-icon-cache >/dev/null
dnf -y -q install $(grep -m1 "^sudo dnf install" /src/README.md | sed "s/^sudo dnf install //") >/dev/null
useradd -m tester
as_user() { runuser -u tester -- env HOME=/home/tester "$@"; }
as_user cp /src/claude-desktop-rpm.sh /tmp/claude-desktop-rpm.sh
check "the user has no sudo rights (so install cannot use sudo)" bash -c "! runuser -u tester -- sudo -n true 2>/dev/null"
snap() { as_user find /home/tester \( -type f -o -type l \) | sed "s|^/home/tester/||" | sort; }
before=$(snap)

echo "== install as a normal user"
as_user bash /tmp/claude-desktop-rpm.sh install
check "app installed into ~/.local" test -x /home/tester/.local/lib/claude-desktop/claude-desktop
check "version prints" bash -c "as_user() { runuser -u tester -- env HOME=/home/tester \"\$@\"; }; as_user /home/tester/.local/bin/claude-desktop-rpm version | grep -q installed:"
check "doctor runs" bash -c "runuser -u tester -- env HOME=/home/tester /home/tester/.local/bin/claude-desktop-rpm doctor >/dev/null"

echo "== every file written is one RESOURCES-AND-GUIDE.md lists"
new=$(comm -13 <(echo "$before") <(snap))
# Documented locations, from the "Files it writes" table.
allowed="^\.local/lib/claude-desktop/|^\.local/bin/(claude-desktop|claude-desktop-rpm|ccd)$|^\.local/share/applications/com\.anthropic\.Claude\.desktop$|^\.local/share/applications/mimeinfo\.cache$|^\.local/share/mime/|^\.local/share/icons/hicolor/|^\.local/share/gnome-shell/search-providers/com\.anthropic\.Claude\.search-provider\.ini$|^\.local/share/dbus-1/services/com\.anthropic\.Claude\.SearchProvider\.service$|^\.config/systemd/user/claude-desktop-rpm-update\.|^\.config/claude-desktop-rpm/"
stray=$(echo "$new" | grep -vE "$allowed" || true)
[ -z "$stray" ] || echo "$stray" | sed "s/^/        not documented: /" >&2
check "no undocumented files ($(echo "$new" | wc -l) written)" test -z "$stray"
for p in .local/lib/claude-desktop/ .local/bin/claude-desktop .local/bin/claude-desktop-rpm .local/share/applications/com.anthropic.Claude.desktop .local/share/mime/packages/com.anthropic.Claude.xml .local/share/gnome-shell/search-providers/ .local/share/dbus-1/services/; do
  check "guide lists ~/$p" grep -qF "~/$p" /src/RESOURCES-AND-GUIDE.md
done

echo "== uninstall leaves the home folder as it found it"
as_user /home/tester/.local/bin/claude-desktop-rpm uninstall
after=$(comm -13 <(echo "$before") <(snap))
# Desktop databases the system tools regenerate; anything else is a leftover.
caches="^\.local/share/applications/mimeinfo\.cache$|^\.local/share/icons/hicolor/icon-theme\.cache$|^\.local/share/mime/(XMLnamespaces|aliases|generic-icons|globs2?|icons|magic|mime\.cache|subclasses|treemagic|types|version)$"
left=$(echo "$after" | grep -vE "$caches" || true)
[ -z "$left" ] || echo "$left" | sed "s/^/        left behind: /" >&2
check "nothing left behind but regenerated caches" test -z "$left"
traces=$(cd /home/tester && echo "$after" | grep . | xargs -r grep -lis "anthropic\|claude" || true)
[ -z "$traces" ] || echo "$traces" | sed "s/^/        still mentions Claude: /" >&2
check "no cache still registers Claude (file types, icons, menu)" test -z "$traces"

[ -n "${SKIP_COWORK:-}" ] && { echo; echo "PASS ($pass checks, cowork skipped)"; exit 0; }

echo "== cowork: only Fedora packages, nothing rpm owns is changed"
dnf -y -q install sudo >/dev/null
echo "tester ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tester
# A container has no KVM or kernel modules: fake the device and stub modprobe (sandbox only).
touch /dev/kvm
printf "#!/bin/sh\nexit 0\n" > /usr/local/sbin/modprobe; chmod +x /usr/local/sbin/modprobe
rpm -qa --qf "%{NAME}\n" | sort > /tmp/pkgs.before
as_user bash /tmp/claude-desktop-rpm.sh cowork
check "edk2-ovmf, qemu and virtiofsd installed" rpm -q edk2-ovmf qemu-system-x86-core virtiofsd >/dev/null
added=$(comm -13 /tmp/pkgs.before <(rpm -qa --qf "%{NAME}\n" | sort))
foreign=$(for p in $added; do dnf -q repoquery --installed --qf "%{from_repo}\n" "$p"; done | sort -u | grep -vxE "fedora|updates|@System|<unknown>|System" || true)
check "new packages come only from Fedora repos ($(echo "$added" | wc -w) added)" test -z "$foreign"
check "rpm -V edk2-ovmf is clean" rpm -V edk2-ovmf
check "firmware at the path the app expects" test -e /usr/share/OVMF/OVMF_CODE.fd
check "vhost_vsock loads at boot" grep -qx vhost_vsock /etc/modules-load.d/vhost_vsock.conf
check "user is in the kvm group" bash -c "id -nG tester | grep -qw kvm"

echo "== cowork repairs links an older release replaced"
ln -sfn /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd
ln -sfn /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd
check "planted links break rpm -V (test is real)" bash -c "! rpm -V edk2-ovmf >/dev/null"
as_user bash /tmp/claude-desktop-rpm.sh cowork
check "rpm -V edk2-ovmf is clean again" rpm -V edk2-ovmf
check "links are the packaged relative ones" test "$(readlink /usr/share/OVMF/OVMF_CODE.fd)" = ../edk2/ovmf/OVMF_CODE.fd

echo
echo "PASS ($pass checks)"
'
