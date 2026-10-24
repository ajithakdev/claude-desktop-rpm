#!/usr/bin/env bash
# End-to-end check: real download from Anthropic, install into a throwaway prefix,
# then update, launcher, version and uninstall. Never touches ~/.local.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/claude-desktop-rpm.sh"
export CLAUDE_DESKTOP_PREFIX
CLAUDE_DESKTOP_PREFIX=$(mktemp -d)
P=$CLAUDE_DESKTOP_PREFIX
trap 'rm -rf "$P"' EXIT

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

echo "== update when current"
check "no re-download when current" grep -q "already up to date" <<< "$("$SCRIPT" update)"
check "version command" grep -q "installed: $v" <<< "$("$SCRIPT" version)"

echo "== launcher picks the theme"
# Swap the app for a stub that prints GTK_THEME, and fake gsettings.
fake=$(mktemp -d); trap 'rm -rf "$P" "$fake"' EXIT
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
