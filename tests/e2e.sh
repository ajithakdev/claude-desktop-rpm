#!/usr/bin/env bash
# End-to-end check: real download from Anthropic, install into a throwaway prefix,
# then update, launcher, version and uninstall. Never touches ~/.local.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/claude-desktop-rpm.sh"
export CLAUDE_DESKTOP_PREFIX
CLAUDE_DESKTOP_PREFIX=$(mktemp -d)
P=$CLAUDE_DESKTOP_PREFIX
running=
trap 'if [ -n "$running" ]; then kill "$running" 2>/dev/null || true; fi; rm -rf "$P"' EXIT

pass=0
fail() { echo "FAIL: $*" >&2; exit 1; }
# check "what" command...: run the command, count a pass or stop.
check() { local what=$1; shift; if "$@"; then echo "  ok: $what"; pass=$((pass + 1)); else fail "$what"; fi; }

echo "== install"
"$SCRIPT" install
check "app binary" test -x "$P/lib/claude-desktop/claude-desktop"
v=$(cat "$P/lib/claude-desktop/.deb-version")
check "version file ($v)" test -n "$v"
check "launcher" test -x "$P/bin/claude-desktop"
check "menu entry points at launcher" grep -q "^Exec=$P/bin/claude-desktop" "$P/share/applications/com.anthropic.Claude.desktop"
check "claude:// handler" grep -q 'x-scheme-handler/claude' "$P/share/applications/com.anthropic.Claude.desktop"
check "icons" test -f "$P/share/icons/hicolor/256x256/apps/claude-desktop.png"
check "script copied to bin" test -x "$P/bin/claude-desktop-rpm"
check "search provider ini" test -f "$P/share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini"
check "search provider runs from the install" grep -q "gjs -m $P/lib/claude-desktop/resources/gnome-search-provider/searchProvider.js" \
  "$P/share/dbus-1/services/com.anthropic.Claude.SearchProvider.service"

echo "== signature must come from the pinned key"
# key.asc with Anthropic's key plus a second key that signs a fake index.
g=$P/.sigtest; mkdir -p "$g"
curl -fsSL --retry 3 https://downloads.claude.ai/claude-desktop/key.asc -o "$g/key.asc"
curl -fsSL --retry 3 https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/InRelease -o "$g/InRelease"
mkdir -m 700 "$g/gpg"; export GNUPGHOME=$g/gpg
gpg -q --import "$g/key.asc" 2>/dev/null
gpg -q --batch --passphrase '' --quick-gen-key attacker@example.invalid ed25519 sign never 2>/dev/null
atk=$(gpg --with-colons -k attacker@example.invalid 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
printf 'Origin: fake\n' | gpg -q --batch --clearsign > "$g/Fake" 2>/dev/null
# A pinned key that expired: made and used 10 days ago, valid for 1 day.
old=$(date -d '-10 days' +%Y%m%dT%H%M%S)
gpg -q --batch --passphrase '' --faked-system-time "$old" --quick-gen-key expired@example.invalid ed25519 sign 1d 2>/dev/null
exp=$(gpg --with-colons -k expired@example.invalid 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}')
printf 'Origin: old\n' | gpg -q --batch --faked-system-time "$old" -u "$exp" --clearsign > "$g/Old" 2>/dev/null
{ cat "$g/InRelease"; printf 'SHA256:\n deadbeef 1 main/binary-amd64/Packages\n'; } > "$g/Appended"
# verify [pin] file: run the script's verify_inrelease, optionally with another pinned key.
verify() { bash -c 'source "$1"; KEY_FPR=${3:-$KEY_FPR}; verify_inrelease "$2" "$2.out"' _ "$SCRIPT" "$@"; }
rejects() { local err; err=$(verify "$@" 2>&1) && return 1; grep -q "not signed by Anthropic's key" <<< "$err"; }
check "fake index is really signed by the second key" verify "$g/Fake" "$atk"
check "real index accepted" verify "$g/InRelease"
check "index signed by the second key rejected" rejects "$g/Fake"
check "expired pinned key rejected" rejects "$g/Old" "$exp"
dropped() { verify "$g/Appended" && ! grep -q deadbeef "$g/Appended.out"; }
check "unsigned text after the signature is dropped" dropped
gpgconf --kill gpg-agent 2>/dev/null || true; unset GNUPGHOME

echo "== update when current"
check "no re-download when current" grep -q "already up to date" <<< "$("$SCRIPT" update)"
check "version command" grep -q "installed: $v" <<< "$("$SCRIPT" version)"
echo 999.0.0 > "$P/lib/claude-desktop/.deb-version"
check "refuses to downgrade" grep -q "older than the installed 999.0.0" <<< "$("$SCRIPT" update 2>&1 || true)"
echo "$v" > "$P/lib/claude-desktop/.deb-version"

echo "== launcher picks the theme"
# Swap the app for a stub that prints GTK_THEME, and fake gsettings.
fake=$P/.fake; mkdir -p "$fake"
mv "$P/lib/claude-desktop/claude-desktop" "$fake/real"
# shellcheck disable=SC2016 # the stub expands GTK_THEME when it runs
printf '#!/bin/sh\necho "theme=${GTK_THEME:-}"\n' > "$P/lib/claude-desktop/claude-desktop"
chmod +x "$P/lib/claude-desktop/claude-desktop"
for scheme in prefer-dark default; do
  printf "#!/bin/sh\necho \"'%s'\"\n" "$scheme" > "$fake/gsettings"; chmod +x "$fake/gsettings"
  got=$(env -u GTK_THEME PATH="$fake:$PATH" "$P/bin/claude-desktop")
  want=theme=; [ "$scheme" = prefer-dark ] && want=theme=Adwaita:dark
  check "$scheme gives '$want' (got '$got')" test "$got" = "$want"
done
got=$(GTK_THEME=Custom PATH="$fake:$PATH" "$P/bin/claude-desktop")
check "user GTK_THEME kept (got '$got')" test "$got" = theme=Custom
mv "$fake/real" "$P/lib/claude-desktop/claude-desktop"

echo "== update while Claude is open is staged, then applied at launch"
app=$P/lib/claude-desktop/claude-desktop
mv "$app" "$fake/real"
cp "$(command -v sleep)" "$app" # a process whose command line starts with the app path
"$app" 120 & running=$!
echo 0.0.1 > "$P/lib/claude-desktop/.deb-version"
check "update refuses while open" bash -c "! '$SCRIPT' update >/dev/null 2>&1"
"$SCRIPT" update --auto >/dev/null
check "--auto stages instead" test "$(cat "$P/lib/claude-desktop.staged/version" 2>/dev/null)" = "$v"
check "app untouched while open" test "$(cat "$P/lib/claude-desktop/.deb-version")" = 0.0.1
check "--auto does not download twice" grep -q "already downloaded" <<< "$("$SCRIPT" update --auto)"
check "apply-staged waits while open" bash -c "'$P/bin/claude-desktop-rpm' apply-staged; test -d '$P/lib/claude-desktop.staged'"
kill "$running"; wait "$running" 2>/dev/null || true
check "launcher applies staged updates" grep -q 'apply-staged' "$P/bin/claude-desktop"
"$P/bin/claude-desktop-rpm" apply-staged
check "staged version installed" test "$(cat "$P/lib/claude-desktop/.deb-version")" = "$v"
check "stage cleared" test ! -e "$P/lib/claude-desktop.staged"
check "real app back in place" cmp -s "$fake/real" "$app"

echo "== doctor"
check "doctor runs" bash -c "'$SCRIPT' doctor >/dev/null"

echo "== uninstall"
"$SCRIPT" uninstall
for f in lib/claude-desktop bin/claude-desktop bin/claude-desktop-rpm share/applications/com.anthropic.Claude.desktop \
  share/gnome-shell/search-providers/com.anthropic.Claude.search-provider.ini share/dbus-1/services/com.anthropic.Claude.SearchProvider.service; do
  check "removed $f" test ! -e "$P/$f"
done

echo "PASS ($pass checks)"
