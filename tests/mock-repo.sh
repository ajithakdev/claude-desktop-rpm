#!/usr/bin/env bash
# Attack tests: a fake apt repository on 127.0.0.1 and full installs into throwaway
# prefixes. Proves every verification step refuses tampered input. Never touches ~/.local.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/claude-desktop-rpm.sh"
REAL_FPR=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE
ARCH=amd64; [ "$(uname -m)" = aarch64 ] && ARCH=arm64
S=$(mktemp -d); SRV=
trap 'if [ -n "$SRV" ]; then kill "$SRV" 2>/dev/null || true; fi; GNUPGHOME=$S/gpg gpgconf --kill gpg-agent 2>/dev/null; rm -rf "$S"' EXIT
PORT=$((20000 + RANDOM % 20000)); URL=http://127.0.0.1:$PORT

# The "attacker" key signs every fake index; some tests pin it to prove the mock itself is valid.
export GNUPGHOME=$S/gpg; mkdir -m 700 "$GNUPGHOME"
gpg -q --batch --passphrase '' --quick-gen-key attacker@example.invalid ed25519 sign never 2>/dev/null
ATK_FPR=$(gpg --with-colons -k attacker@example.invalid 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
gpg -q --armor --export "$ATK_FPR" > "$S/attacker.asc"
curl -fsSL --retry 3 https://downloads.claude.ai/claude-desktop/key.asc -o "$S/anthropic.asc"
cat "$S/anthropic.asc" "$S/attacker.asc" > "$S/both.asc"

# build_repo <key.asc to serve> <version> [tamper]: a signed repo holding one tiny fake package.
build_repo() {
  local keyfile=$1 version=$2 tamper=${3:-} m=$S/www k=$S/pkg
  local deb=pool/main/c/claude-desktop/claude-desktop_${version}_$ARCH.deb idx=dists/stable/main/binary-$ARCH/Packages
  rm -rf "${m:?}"/* "$k"; mkdir -p "$m/${idx%/*}" "$m/${deb%/*}" "$k/root/usr/lib/claude-desktop" \
    "$k/root/usr/share/applications" "$k/root/usr/share/icons/hicolor/256x256/apps"
  printf '#!/bin/sh\necho fake\n' > "$k/root/usr/lib/claude-desktop/claude-desktop"
  chmod +x "$k/root/usr/lib/claude-desktop/claude-desktop"
  printf '[Desktop Entry]\nName=Claude\nExec=claude-desktop %%u\n' > "$k/root/usr/share/applications/com.anthropic.Claude.desktop"
  : > "$k/root/usr/share/icons/hicolor/256x256/apps/claude-desktop.png"
  (cd "$k" && echo 2.0 > debian-binary && echo 'Package: claude-desktop' > control && tar -cJf control.tar.xz control \
    && tar -cJf data.tar.xz -C root . && ar rc "$m/$deb" debian-binary control.tar.xz data.tar.xz)

  local dsha path=$deb
  dsha=$(sha256sum "$m/$deb" | cut -d' ' -f1)
  [ "$tamper" = deb ] && dsha=$(printf '0%.0s' {1..64})
  [ "$tamper" = path ] && path=pool/main/c/claude-desktop/../../evil.deb
  printf 'Package: claude-desktop\nVersion: %s\nFilename: %s\nSHA256: %s\n' "$version" "$path" "$dsha" > "$m/$idx"
  local psha psize
  psha=$(sha256sum "$m/$idx" | cut -d' ' -f1); psize=$(stat -c%s "$m/$idx")
  [ "$tamper" = packages ] && echo '# tampered' >> "$m/$idx"

  local until=+7 vu
  [ "$tamper" = expired ] && until=-1
  vu="Valid-Until: $(date -u -d "$until days" '+%a, %d %b %Y %H:%M:%S UTC')"
  [ "$tamper" = novaliduntil ] && vu=
  printf 'Origin: Mock\nSuite: stable\n%s\nSHA256:\n %s %s main/binary-%s/Packages\n' "$vu" "$psha" "$psize" "$ARCH" > "$S/Release"
  gpg -q --batch -u "$ATK_FPR" --clearsign -o "$m/dists/stable/InRelease" "$S/Release" 2>/dev/null
  [ "$tamper" = badsig ] && sed -i 's/^Origin: Mock/Origin: Mocc/' "$m/dists/stable/InRelease"
  cp "$keyfile" "$m/key.asc"
}

# pin <fingerprint>: the script with its URLs pointed at the mock and that key pinned.
pin() {
  sed -e "s|^REPO=.*|REPO=$URL|" -e "s|^KEY_URL=.*|KEY_URL=$URL/key.asc|" -e "s|^KEY_FPR=.*|KEY_FPR=$1|" \
    "$SCRIPT" > "$S/run.sh"
  chmod +x "$S/run.sh"
}

pass=0 failed=0
# run <what> <installed|refused> <text the output must contain> [prefix to reuse]
run() {
  local p=${4:-$(mktemp -d -p "$S")} out rc got=refused
  out=$(env -u GNUPGHOME -u XDG_CONFIG_HOME CLAUDE_DESKTOP_PREFIX="$p" HOME="$p/home" "$S/run.sh" install 2>&1); rc=$?
  if [ $rc -eq 0 ] && grep -q '^echo fake' "$p/lib/claude-desktop/claude-desktop" 2>/dev/null; then got=installed; fi
  if [ "$got" = "$2" ] && grep -q "$3" <<< "$out"; then
    echo "  ok: $1 ($got)"; pass=$((pass + 1))
  else
    echo "FAIL: $1 ($got, wanted $2 with '$3')" >&2; tail -3 <<< "$out" >&2; failed=$((failed + 1))
  fi
}

mkdir -p "$S/www"
python3 -m http.server -b 127.0.0.1 -d "$S/www" "$PORT" >/dev/null 2>&1 & SRV=$!
for _ in $(seq 50); do curl -fs "$URL/" >/dev/null && break; sleep 0.1; done

echo "== key.asc carries Anthropic's key and a second key, which signs the index"
build_repo "$S/both.asc" 99.0.0; pin "$REAL_FPR"
run "second key's signature refused" refused "not signed by Anthropic's key"

echo "== key.asc without Anthropic's key"
build_repo "$S/attacker.asc" 99.0.0; pin "$REAL_FPR"
run "missing pinned key refused" refused "fingerprint mismatch"

echo "== the mock is a valid repo when its own key is pinned"
build_repo "$S/attacker.asc" 99.0.0; pin "$ATK_FPR"
keep=$(mktemp -d -p "$S")
run "clean repo installs" installed "installed Claude Desktop 99.0.0" "$keep"

echo "== an older, validly signed index does not roll back"
build_repo "$S/attacker.asc" 98.0.0
run "downgrade refused" refused "older than the installed 99.0.0" "$keep"

echo "== each tampered step is refused"
for t in badsig expired novaliduntil packages deb path; do
  case $t in
    badsig) want="signature check failed" ;;
    expired) want="index expired" ;;
    novaliduntil) want="no readable Valid-Until" ;;
    packages) want="Packages index checksum mismatch" ;;
    deb) want="package checksum mismatch" ;;
    path) want="unexpected package path" ;;
  esac
  build_repo "$S/attacker.asc" 99.0.0 "$t"
  run "tampered $t" refused "$want"
done

[ "$failed" -eq 0 ] || { echo "FAILED ($failed of $((pass + failed)))" >&2; exit 1; }
echo "PASS ($pass checks)"
