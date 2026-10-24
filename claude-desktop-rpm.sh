#!/usr/bin/env bash
# Install and update Anthropic's official Claude Desktop (Linux beta) on Fedora.
# Unofficial helper: downloads Anthropic's signed .deb from downloads.claude.ai,
# verifies it, and unpacks it into ~/.local. No Anthropic files are redistributed.
set -euo pipefail

REPO=https://downloads.claude.ai/claude-desktop/apt/stable
KEY_URL=https://downloads.claude.ai/claude-desktop/key.asc
KEY_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
# Never follow a redirect off HTTPS; give up on dead or stalled downloads instead of hanging the timer.
CURL_OPTS=(--proto-redir '=https' --connect-timeout 20 --speed-limit 1024 --speed-time 60)
ARCH=amd64
[ "$(uname -m)" = aarch64 ] && ARCH=arm64

PREFIX="${CLAUDE_DESKTOP_PREFIX:-$HOME/.local}"
APP_DIR="$PREFIX/lib/claude-desktop"
STAGE_DIR="$PREFIX/lib/claude-desktop.staged"
BIN_DIR="$PREFIX/bin"
SELF="$BIN_DIR/claude-desktop-rpm"
SHARE_DIR="$PREFIX/share"
DESKTOP_FILE="$SHARE_DIR/applications/com.anthropic.Claude.desktop"
SEARCH_INI="$SHARE_DIR/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini"
SEARCH_SERVICE="$SHARE_DIR/dbus-1/services/com.anthropic.Claude.SearchProvider.service"
VERSION_FILE="$APP_DIR/.deb-version"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT=claude-desktop-rpm-update
NO_AUTO_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/claude-desktop-rpm/no-auto-update"

die() { echo "error: $*" >&2; exit 1; }
log() { echo "==> $*"; }
notify() { command -v notify-send >/dev/null || return 0; notify-send -a Claude -i claude-desktop "$@" 2>/dev/null || true; }

[ "$(id -u)" -ne 0 ] || die "run this as your normal user, not root (cowork asks for sudo itself)"

need() {
  local missing=()
  for c in "$@"; do command -v "$c" >/dev/null || missing+=("$c"); done
  [ ${#missing[@]} -eq 0 ] || die "missing tools: ${missing[*]} (try: sudo dnf install curl gnupg2 binutils tar coreutils)"
}

installed_version() { cat "$VERSION_FILE" 2>/dev/null || echo none; }
app_running() { pgrep -f "^$APP_DIR/claude-desktop" >/dev/null; }

# Writes the signed text of $1 to $2, only if the pinned key itself made a good signature.
# A good signature alone is not enough: key.asc could carry a second key.
verify_inrelease() {
  local status=$2.status
  gpg -q --status-fd 3 --decrypt "$1" 3>"$status" >"$2" 2>/dev/null || die "InRelease signature check failed"
  # VALIDSIG: field 3 is the signing (sub)key, the last field its primary key.
  # GOODSIG (by long key ID) is only printed when that key is not expired or revoked.
  awk -v k="$KEY_FPR" '
    $2 == "GOODSIG" { good[$3] = 1 }
    $2 == "VALIDSIG" && $NF == k { pinned[substr($3, length($3) - 15)] = 1 }
    END { for (id in pinned) if (id in good) exit 0; exit 1 }' "$status" \
    || die "InRelease is not signed by Anthropic's key ($KEY_FPR), or that key is expired or revoked"
  rm -f "$status"
}

# Prints "version<TAB>filename<TAB>sha256" of the newest package in the signed index.
latest_package() {
  local work=$1
  curl "${CURL_OPTS[@]}" -fsSLo "$work/key.asc" "$KEY_URL"
  export GNUPGHOME="$work/gnupg"; mkdir -m 700 "$GNUPGHOME"
  gpg -q --import "$work/key.asc" 2>/dev/null
  gpg --with-colons --list-keys | grep -q "^fpr:::::::::$KEY_FPR:" || die "signing key fingerprint mismatch"

  curl "${CURL_OPTS[@]}" -fsSLo "$work/InRelease" "$REPO/dists/stable/InRelease"
  verify_inrelease "$work/InRelease" "$work/Release"

  # An expired index could be an old signed copy replayed to hold back updates.
  local until until_s
  until=$(sed -n 's/^Valid-Until: //p' "$work/Release")
  if [ -z "$until" ] || ! until_s=$(date -d "$until" +%s 2>/dev/null); then
    die "Anthropic's index has no readable Valid-Until date"
  fi
  [ "$until_s" -ge "$(date +%s)" ] || die "Anthropic's index expired on $until (stale mirror or replay); try again later"

  curl "${CURL_OPTS[@]}" -fsSLo "$work/Packages" "$REPO/dists/stable/main/binary-$ARCH/Packages"
  local want got
  want=$(awk -v p="main/binary-$ARCH/Packages" '/^SHA256:/{s=1;next} /^[^ ]/{s=0} s && $3==p {print $1}' "$work/Release")
  got=$(sha256sum "$work/Packages" | cut -d' ' -f1)
  if [ -z "$want" ] || [ "$want" != "$got" ]; then die "Packages index checksum mismatch"; fi

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

write_launcher() {
  rm -f "$BIN_DIR/claude-desktop" # new inode, so a launcher that is running right now is not rewritten under it
  cat > "$BIN_DIR/claude-desktop" <<LAUNCHER
#!/bin/sh
# Written by claude-desktop-rpm.
# An update downloaded while Claude was open waits here; put it in place before starting.
if [ -d "$STAGE_DIR" ] && [ -x "$SELF" ]; then CLAUDE_DESKTOP_PREFIX="$PREFIX" "$SELF" apply-staged >/dev/null 2>&1 || true; fi
# Electron ignores GNOME's dark style (the portal's color-scheme) and reads only the
# GTK theme name, so the "System" theme shows light. Pick a dark GTK theme instead.
if [ -z "\${GTK_THEME:-}" ] && gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -q dark; then
  export GTK_THEME=Adwaita:dark
fi
exec "$APP_DIR/claude-desktop" "\$@"
LAUNCHER
  chmod +x "$BIN_DIR/claude-desktop"
}

# $1: unpacked .deb root, $2: version.
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

  write_launcher
  [ -x "$APP_DIR/resources/bin/ccd" ] && ln -sfn "$APP_DIR/resources/bin/ccd" "$BIN_DIR/ccd"
  cp -a "$root/usr/share/icons/hicolor" "$SHARE_DIR/icons/"
  sed "s|^Exec=claude-desktop|Exec=$BIN_DIR/claude-desktop|" \
    "$root/usr/share/applications/com.anthropic.Claude.desktop" > "$DESKTOP_FILE"
  cp "$APP_DIR/resources/linux-mime/com.anthropic.Claude.xml" "$SHARE_DIR/mime/packages/" 2>/dev/null || true

  # GNOME search provider: lists Claude sessions in the Activities search.
  local sp="$APP_DIR/resources/gnome-search-provider"
  if [ -f "$sp/com.anthropic.Claude.search-provider.ini" ]; then
    mkdir -p "$(dirname "$SEARCH_INI")" "$(dirname "$SEARCH_SERVICE")"
    cp "$sp/com.anthropic.Claude.search-provider.ini" "$SEARCH_INI"
    sed "s|/usr/lib/claude-desktop|$APP_DIR|g" "$sp/com.anthropic.Claude.SearchProvider.service" > "$SEARCH_SERVICE"
  fi

  update-desktop-database "$SHARE_DIR/applications" 2>/dev/null || true
  update-mime-database "$SHARE_DIR/mime" 2>/dev/null || true
  gtk-update-icon-cache -f -t "$SHARE_DIR/icons/hicolor" 2>/dev/null || true
}

# Keep a copy of this script on PATH so the timer and the launcher can call it.
install_self() {
  local me; me=$(realpath "$0")
  [ "$me" = "$(realpath -m "$SELF")" ] && return
  mkdir -p "$BIN_DIR"; install -m 755 "$me" "$SELF"
}

# $1: "" or --force or --auto (the timer: stage the update if Claude is open).
cmd_install() {
  local mode=${1:-}
  need curl gpg ar tar sha256sum awk
  # Global, not local: the EXIT trap runs after this function returns.
  work=$(mktemp -d); trap 'rm -rf "$work"' EXIT

  log "checking Anthropic's signed repository"
  local line version file sha
  line=$(latest_package "$work")
  IFS=$'\t' read -r version file sha <<< "$line"
  if [ -z "$version" ] || [ -z "$file" ] || [ -z "$sha" ]; then die "could not find claude-desktop in the index"; fi
  case "$file" in pool/main/c/claude-desktop/*.deb) ;; *) die "unexpected package path: $file" ;; esac
  [ "${file#pool/main/c/claude-desktop/}" = "${file##*/}" ] || die "unexpected package path: $file"

  local current; current=$(installed_version)
  install_self
  if [ "$current" = "$version" ] && [ "$mode" != --force ]; then
    log "already up to date ($version)"; first_run_setup; return
  fi
  # A replayed older index (still inside Valid-Until) must not roll the app back.
  if [ "$current" != none ] && [ "$mode" != --force ] \
    && [ "$(printf '%s\n' "$current" "$version" | sort -V | tail -n1)" != "$version" ]; then
    die "the index offers $version, older than the installed $current; use update --force to downgrade"
  fi
  if [ "$mode" = --auto ] && [ "$(cat "$STAGE_DIR/version" 2>/dev/null)" = "$version" ]; then
    log "$version is already downloaded and waits for the next launch"; return
  fi
  if app_running && [ "$mode" != --auto ]; then
    die "Claude Desktop is running; quit it first (tray icon > Quit), then re-run"
  fi

  log "downloading $version (installed: $current)"
  curl "${CURL_OPTS[@]}" -fL --progress-bar -o "$work/pkg.deb" "$REPO/$file"
  [ "$(sha256sum "$work/pkg.deb" | cut -d' ' -f1)" = "$sha" ] || die "package checksum mismatch"

  log "unpacking"
  mkdir "$work/deb" "$work/root"
  (cd "$work/deb" && ar x ../pkg.deb)
  tar -xf "$work"/deb/data.tar.* -C "$work/root"

  if app_running; then
    rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"
    mv "$work/root" "$STAGE_DIR/root"; echo "$version" > "$STAGE_DIR/version"
    log "Claude is open: $version is ready and installs the next time you open Claude"
    notify "Claude Desktop $version is ready" "It installs the next time you open Claude."
    return
  fi
  install_files "$work/root" "$version"
  rm -rf "$STAGE_DIR"
  log "installed Claude Desktop $version into $PREFIX"
  [ "$mode" = --auto ] && notify "Claude Desktop updated to $version"
  first_run_setup
}

# Called by the launcher before Claude starts.
cmd_apply_staged() {
  [ -d "$STAGE_DIR/root" ] || { rm -rf "$STAGE_DIR"; return; }
  app_running && return # a second launch only focuses the open window
  local version; version=$(cat "$STAGE_DIR/version")
  [ "$version" != "$(installed_version)" ] && install_files "$STAGE_DIR/root" "$version"
  rm -rf "$STAGE_DIR"
}

# Things that only need doing once per machine, after the app is in place.
first_run_setup() {
  [ "$PREFIX" = "$HOME/.local" ] && [ ! -e "$NO_AUTO_FILE" ] && enable_timer
  tray_hint
}

enable_timer() {
  command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1 || return 0
  mkdir -p "$UNIT_DIR"
  cat > "$UNIT_DIR/$UNIT.service" <<EOF
[Unit]
Description=Update Claude Desktop from Anthropic's signed repository
After=network-online.target

[Service]
Type=oneshot
ExecStart=$SELF update --auto
EOF
  cat > "$UNIT_DIR/$UNIT.timer" <<EOF
[Unit]
Description=Check for Claude Desktop updates daily

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF
  systemctl --user daemon-reload
  systemctl --user is-enabled -q "$UNIT.timer" 2>/dev/null && return
  systemctl --user enable --now -q "$UNIT.timer"
  log "auto-update on: checks daily (turn off with: claude-desktop-rpm auto-update off)"
}

disable_timer() {
  systemctl --user disable --now -q "$UNIT.timer" 2>/dev/null || true
  rm -f "$UNIT_DIR/$UNIT.service" "$UNIT_DIR/$UNIT.timer"
  systemctl --user daemon-reload 2>/dev/null || true
}

cmd_auto_update() {
  case "${1:-}" in
    on)  rm -f "$NO_AUTO_FILE"; [ -x "$SELF" ] || install_self; enable_timer ;;
    off) disable_timer; mkdir -p "$(dirname "$NO_AUTO_FILE")"; touch "$NO_AUTO_FILE"; log "auto-update off" ;;
    *)   systemctl --user is-active -q "$UNIT.timer" 2>/dev/null && echo "auto-update: on" || echo "auto-update: off" ;;
  esac
}

TRAY_EXT=appindicatorsupport@rgcjonas.gmail.com
tray_on_gnome() { gnome-extensions list --enabled 2>/dev/null | grep -q appindicator; }
# Installed but off needs only the enable step.
tray_fix() {
  if gnome-extensions info "$TRAY_EXT" >/dev/null 2>&1; then
    echo "gnome-extensions enable $TRAY_EXT"
  else
    echo "sudo dnf install gnome-shell-extension-appindicator, log out and in, then gnome-extensions enable $TRAY_EXT"
  fi
}

tray_hint() {
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && ! tray_on_gnome || return 0
  log "GNOME hides tray icons, and Claude's tray menu has Quit. To show it, run:"
  echo "    $(tray_fix)"
}

our_launcher()      { grep -q claude-desktop-rpm "$BIN_DIR/claude-desktop"; }
timer_on()          { systemctl --user is-active -q "$UNIT.timer"; }
keyring_running()   { busctl --user status org.freedesktop.secrets; }
in_kvm_group()      { id -nG "$USER" | grep -qw kvm; }
has_virtiofsd()     { [ -x /usr/libexec/virtiofsd ] || command -v virtiofsd; }
has_shortcuts_portal() {
  gdbus introspect --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop \
    | grep -q org.freedesktop.portal.GlobalShortcuts
}

cmd_doctor() {
  local bad=0
  # probe "ok text" "problem" "fix" command...
  probe() {
    local good=$1 problem=$2 fix=$3; shift 3
    if "$@" >/dev/null 2>&1; then echo "  ok    $good"; else echo "  warn  $problem"; echo "        fix: $fix"; bad=1; fi
  }

  echo "Claude Desktop"
  probe "installed: $(installed_version)" "not installed" "$0 install" test -x "$APP_DIR/claude-desktop"
  probe "launcher (dark mode fix, staged updates)" "old launcher without the dark mode fix" "$0 update --force" our_launcher
  if [ -d "$STAGE_DIR/root" ]; then echo "  ok    update $(cat "$STAGE_DIR/version") waits for the next launch"; fi
  probe "auto-update on" "auto-update off" "$0 auto-update on" timer_on
  probe "GNOME search provider" "GNOME search provider missing" "$0 update --force" test -f "$SEARCH_INI"

  echo "Desktop"
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    probe "tray icon (AppIndicator extension on)" "tray icon hidden: GNOME needs the AppIndicator extension" \
      "$(tray_fix)" tray_on_gnome
  fi
  probe "keyring (sign-in is saved)" "no keyring: you will sign in on every launch" \
    "sudo dnf install gnome-keyring (or use KDE Wallet on Plasma), then unlock it" keyring_running
  if [ "${XDG_SESSION_TYPE:-}" = wayland ]; then
    probe "Quick Entry hotkey (GlobalShortcuts portal)" "Quick Entry hotkey needs the GlobalShortcuts portal on Wayland" \
      "install your desktop's portal backend (xdg-desktop-portal-gnome or -kde)" has_shortcuts_portal
  fi

  echo "Cowork"
  probe "/dev/kvm" "/dev/kvm missing" "turn on SVM or VT-x in your BIOS" test -e /dev/kvm
  probe "in the kvm group" "not in the kvm group" "$0 cowork, then log out and in" in_kvm_group
  probe "/dev/vhost-vsock" "vhost_vsock not loaded" "$0 cowork" test -e /dev/vhost-vsock
  probe "QEMU" "QEMU missing" "$0 cowork" command -v qemu-system-x86_64
  probe "UEFI firmware at the path Claude expects" "firmware link missing" "$0 cowork" test -e /usr/share/OVMF/OVMF_CODE.fd
  probe "virtiofsd" "virtiofsd missing" "$0 cowork" has_virtiofsd

  if [ $bad = 0 ]; then echo "All good."; else echo "Fix the warnings above, then restart Claude."; fi
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
  app_running && die "Claude Desktop is running; quit it first (tray icon > Quit), then re-run"
  [ "$PREFIX" = "$HOME/.local" ] && disable_timer
  rm -rf "$APP_DIR" "$STAGE_DIR" "$DESKTOP_FILE" "$SHARE_DIR/mime/packages/com.anthropic.Claude.xml" "$SEARCH_INI" "$SEARCH_SERVICE"
  rm -f "$BIN_DIR/claude-desktop" "$SELF"
  [ "$(readlink "$BIN_DIR/ccd" 2>/dev/null)" = "$APP_DIR/resources/bin/ccd" ] && rm -f "$BIN_DIR/ccd"
  find "$SHARE_DIR/icons/hicolor" -name 'claude-desktop.png' -delete 2>/dev/null || true
  update-desktop-database "$SHARE_DIR/applications" 2>/dev/null || true
  log "removed Claude Desktop (your sign-in and chats in ~/.config/Claude are kept)"
}

# Sourced (by tests): define functions only.
[ "${BASH_SOURCE[0]:-$0}" = "$0" ] || return 0

case "${1:-}" in
  install|update) cmd_install "${2:-}" ;;
  apply-staged)   cmd_apply_staged ;;
  auto-update)    cmd_auto_update "${2:-}" ;;
  doctor)         cmd_doctor ;;
  cowork)         cmd_cowork ;;
  uninstall)      cmd_uninstall ;;
  version)        echo "installed: $(installed_version)" ;;
  *) echo "usage: $0 {install|update [--force]|auto-update [on|off]|doctor|cowork|uninstall|version}"; exit 1 ;;
esac
