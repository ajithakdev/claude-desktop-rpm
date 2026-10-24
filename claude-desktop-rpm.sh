#!/usr/bin/env bash
# Install and update Anthropic's official Claude Desktop (Linux beta) on Fedora.
# Unofficial helper: downloads Anthropic's signed .deb from downloads.claude.ai,
# verifies it, and unpacks it into ~/.local. No Anthropic files are redistributed.
set -euo pipefail

REPO=https://downloads.claude.ai/claude-desktop/apt/stable
KEY_URL=https://downloads.claude.ai/claude-desktop/key.asc
KEY_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
ARCH=amd64
[ "$(uname -m)" = aarch64 ] && ARCH=arm64

PREFIX="${CLAUDE_DESKTOP_PREFIX:-$HOME/.local}"
APP_DIR="$PREFIX/lib/claude-desktop"
BIN_DIR="$PREFIX/bin"
SHARE_DIR="$PREFIX/share"
DESKTOP_FILE="$SHARE_DIR/applications/com.anthropic.Claude.desktop"
VERSION_FILE="$APP_DIR/.deb-version"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }

need() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null || missing+=("$c"); done
  [ ${#missing[@]} -eq 0 ] || die "missing tools: ${missing[*]} (try: sudo dnf install curl gnupg2 binutils tar coreutils)"
}

installed_version() { cat "$VERSION_FILE" 2>/dev/null || echo none; }

# Prints "version<TAB>filename<TAB>sha256" of the newest package in the signed index.
latest_package() {
  local work=$1
  curl -fsSLo "$work/key.asc" "$KEY_URL"
  export GNUPGHOME="$work/gnupg"; mkdir -m 700 "$GNUPGHOME"
  gpg -q --import "$work/key.asc" 2>/dev/null
  gpg --with-colons --list-keys | grep -q "^fpr:::::::::$KEY_FPR:" || die "signing key fingerprint mismatch"

  curl -fsSLo "$work/InRelease" "$REPO/dists/stable/InRelease"
  # --decrypt prints only the signed text, and fails on a bad signature.
  gpg -q --decrypt "$work/InRelease" > "$work/Release" 2>/dev/null || die "InRelease signature check failed"

  curl -fsSLo "$work/Packages" "$REPO/dists/stable/main/binary-$ARCH/Packages"
  local want got
  want=$(awk -v p="main/binary-$ARCH/Packages" '/^SHA256:/{s=1;next} /^[^ ]/{s=0} s && $3==p {print $1}' "$work/Release")
  got=$(sha256sum "$work/Packages" | cut -d' ' -f1)
  [ -n "$want" ] && [ "$want" = "$got" ] || die "Packages index checksum mismatch"

  awk -v RS= -F'\n' '/(^|\n)Package: claude-desktop(\n|$)/ {
      v=f=s=""
      for (i=1;i<=NF;i++) {
        if ($i ~ /^Version: /)  v=substr($i,10)
        if ($i ~ /^Filename: /) f=substr($i,11)
        if ($i ~ /^SHA256: /)   s=substr($i,9)
      }
      print v "\t" f "\t" s
    }' "$work/Packages" | sort -V -k1,1 | tail -n1
}

install_files() {
  local root=$1 version=$2
  mkdir -p "$PREFIX/lib" "$BIN_DIR" "$SHARE_DIR/applications" "$SHARE_DIR/icons" "$SHARE_DIR/mime/packages"

  # Swap the app directory in one step so a failed copy never leaves a half install.
  rm -rf "$APP_DIR.new" "$APP_DIR.old"
  cp -a "$root/usr/lib/claude-desktop" "$APP_DIR.new"
  echo "$version" > "$APP_DIR.new/.deb-version"
  [ -d "$APP_DIR" ] && mv "$APP_DIR" "$APP_DIR.old"
  mv "$APP_DIR.new" "$APP_DIR"
  rm -rf "$APP_DIR.old"

  ln -sfn "$APP_DIR/claude-desktop" "$BIN_DIR/claude-desktop"
  [ -x "$APP_DIR/resources/bin/ccd" ] && ln -sfn "$APP_DIR/resources/bin/ccd" "$BIN_DIR/ccd"
  cp -a "$root/usr/share/icons/hicolor" "$SHARE_DIR/icons/"
  sed "s|^Exec=claude-desktop|Exec=$BIN_DIR/claude-desktop|" \
    "$root/usr/share/applications/com.anthropic.Claude.desktop" > "$DESKTOP_FILE"
  cp "$APP_DIR/resources/linux-mime/com.anthropic.Claude.xml" "$SHARE_DIR/mime/packages/" 2>/dev/null || true

  update-desktop-database "$SHARE_DIR/applications" 2>/dev/null || true
  update-mime-database "$SHARE_DIR/mime" 2>/dev/null || true
  gtk-update-icon-cache -f -t "$SHARE_DIR/icons/hicolor" 2>/dev/null || true
}

cmd_install() {
  local force=${1:-}
  need curl gpg ar tar sha256sum awk
  # Global, not local: the EXIT trap runs after this function returns.
  work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

  log "checking Anthropic's signed repository"
  local line version file sha
  line=$(latest_package "$work")
  IFS=$'\t' read -r version file sha <<< "$line"
  [ -n "$version" ] && [ -n "$file" ] && [ -n "$sha" ] || die "could not find claude-desktop in the index"
  case "$file" in pool/main/c/claude-desktop/*.deb) ;; *) die "unexpected package path: $file" ;; esac

  local current; current=$(installed_version)
  if [ "$current" = "$version" ] && [ "$force" != --force ]; then
    log "already up to date ($version)"; return
  fi
  if pgrep -f "$APP_DIR/claude-desktop" >/dev/null; then
    die "Claude Desktop is running; quit it first (tray icon > Quit), then re-run"
  fi

  log "downloading $version (installed: $current)"
  curl -fL --progress-bar -o "$work/pkg.deb" "$REPO/$file"
  [ "$(sha256sum "$work/pkg.deb" | cut -d' ' -f1)" = "$sha" ] || die "package checksum mismatch"

  log "unpacking"
  mkdir "$work/deb" "$work/root"
  (cd "$work/deb" && ar x ../pkg.deb)
  tar -xf "$work"/deb/data.tar.* -C "$work/root"
  install_files "$work/root" "$version"
  log "installed Claude Desktop $version into $PREFIX"
}

cmd_cowork() {
  # Cowork runs tasks in a QEMU/KVM VM. The app looks for firmware only at
  # Debian's /usr/share/OVMF path, so link Fedora's edk2 files there.
  [ -e /dev/kvm ] || die "/dev/kvm missing: enable SVM/VT-x virtualization in your BIOS"
  log "installing QEMU, OVMF firmware and virtiofsd (sudo)"
  sudo dnf install -y qemu-system-x86-core edk2-ovmf virtiofsd
  sudo mkdir -p /usr/share/OVMF
  sudo ln -sfn /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd
  sudo ln -sfn /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd
  echo vhost_vsock | sudo tee /etc/modules-load.d/vhost_vsock.conf >/dev/null
  sudo modprobe vhost_vsock
  if ! id -nG "$USER" | grep -qw kvm; then
    sudo usermod -aG kvm "$USER"
    log "added $USER to the kvm group: log out and back in"
  fi
  log "Cowork prerequisites ready; restart Claude Desktop"
}

cmd_uninstall() {
  rm -rf "$APP_DIR" "$DESKTOP_FILE" "$SHARE_DIR/mime/packages/com.anthropic.Claude.xml"
  rm -f "$BIN_DIR/claude-desktop"
  [ "$(readlink "$BIN_DIR/ccd" 2>/dev/null)" = "$APP_DIR/resources/bin/ccd" ] && rm -f "$BIN_DIR/ccd"
  find "$SHARE_DIR/icons/hicolor" -name 'claude-desktop.png' -delete 2>/dev/null || true
  update-desktop-database "$SHARE_DIR/applications" 2>/dev/null || true
  log "removed Claude Desktop (your sign-in and chats in ~/.config/Claude are kept)"
}

case "${1:-}" in
  install|update) cmd_install "${2:-}" ;;
  cowork)         cmd_cowork ;;
  uninstall)      cmd_uninstall ;;
  version)        echo "installed: $(installed_version)" ;;
  *) echo "usage: $0 {install|update [--force]|cowork|uninstall|version}"; exit 1 ;;
esac
