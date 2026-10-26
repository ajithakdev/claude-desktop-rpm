#!/usr/bin/env bash
# Static checks against Fedora's rules: Fedora Magazine content and style tips
# (docs.fedoraproject.org/en-US/fedora-magazine/writing-guidelines/), the Fedora
# AI-Assisted Contributions Policy, and what the Magazine editors asked for in
# discussion.fedoraproject.org/t/205949. Offline; reads files only.
# shellcheck disable=SC2016 # the bash -c snippets expand their own $1
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
SCRIPT=claude-desktop-rpm.sh
mapfile -t DOCS < <(git ls-files '*.md' '.github/*.yml' '.github/ISSUE_TEMPLATE/*')
mapfile -t TEXT < <(git ls-files | grep -vE '\.(png|jpg|svg)$')

pass=0 failed=0
# check "what" command...: run the command, count a pass or a failure (keep going, report all).
check() { local what=$1; shift; if "$@"; then echo "  ok: $what"; pass=$((pass + 1)); else echo "FAIL: $what" >&2; failed=$((failed + 1)); fi; }
# none "what" pattern files...: passes when grep finds nothing, prints the hits otherwise.
none() { local what=$1 pat=$2; shift 2; local hits; hits=$(grep -nIE "$pat" "$@" 2>/dev/null); [ -z "$hits" ] || echo "${hits//$'\n'/$'\n'        }" | sed '1s/^/        /' >&2; check "$what" test -z "$hits"; }

echo "== system changes (Magazine: leave packaged files alone, prefer official packages)"
none "no sudo command writes under /usr" '^\s*sudo .*[ =>]/usr/' "$SCRIPT"
none "no third-party repos (Copr, config-manager, .repo files)" 'copr|config-manager|addrepo|\.repo\b|rpmfusion' "$SCRIPT"
none "no rpm installs from URLs and no curl | sh" 'rpm -[iU]|dnf install[^"]*https?:|curl[^|]*\|\s*(ba)?sh' "$SCRIPT"
check "every sudo dnf call is install or reinstall from Fedora's repos" \
  bash -c '! grep -nE "^\s*sudo dnf" "$1" | grep -vE "sudo dnf (install|reinstall) -y [a-z0-9 -]+$"' _ "$SCRIPT"
check "the app install never runs sudo (only cmd_cowork does)" \
  bash -c '! sed "/^cmd_cowork() {/,/^}/d" "$1" | grep -qE "^\s*sudo "' _ "$SCRIPT"
check "refuses to run as root" grep -q 'id -u)" -ne 0 ] || die' "$SCRIPT"
check "only contacts downloads.claude.ai" \
  bash -c '! grep -oE "https?://[^/\" ]+" "$1" | grep -v "^https://downloads.claude.ai$"' _ "$SCRIPT"

echo "== licensing and disclosure (Fedora AI policy, editors' requests)"
check "LICENSE is MIT" grep -q '^MIT License' LICENSE
check "script carries an SPDX MIT header" grep -q '^# SPDX-License-Identifier: MIT$' "$SCRIPT"
check "README says Claude Desktop is proprietary" grep -q "proprietary" README.md
check "README says Chat works on the Free plan" grep -qiE 'Chat works on every plan, including Free' README.md
check "README says Claude Code and Cowork need a paid plan" grep -qE 'Claude Code and Cowork need a paid plan' README.md
check "README links Anthropic's terms and says it is not affiliated" \
  bash -c 'grep -q "anthropic.com/legal" README.md && grep -qi "not affiliated" README.md'
check "README discloses AI help (Credits)" grep -qE 'Written with help from Claude' README.md

echo "== writing style (Magazine writing guidelines)"
none "no em or en dashes" $'–|—' "${TEXT[@]}"
none "no exclusionary terms (allowlist/denylist, primary/replica)" '\b(black|white)list|\bslave\b|\bmaster (branch|key|node)' "${TEXT[@]}"
none "US spelling" '\b(colour|behaviour|favourite|organis(e|ed|ing)|recognis(e|ed)|artefact|centre|licence|initialis(e|ed)|customis(e|ed)|optimis(e|ed)|catalogue)s?\b' "${DOCS[@]}" "$SCRIPT"
none "third-party names styled as their owners do (Copr, NVIDIA, Red Hat, GitHub, GNOME)" '\bCOPR\b|\bNvidia\b|\bRedhat\b|\bRedHat\b|\bGithub\b|\bGnome\b' "${DOCS[@]}"
check "headings use sentence case" python3 - "${DOCS[@]}" <<'EOF'
import re, sys
# Words that keep their capitals: names, acronyms and file names.
keep = set("""Claude Desktop Code Cowork Fedora GNOME KDE Plasma RHEL Rocky Alma AlmaLinux Anthropic
GitHub Copr TL;DR FAQ README CHANGELOG CONTRIBUTING SECURITY HANDOFF CODEMAP SEO PR CI KVM QEMU OVMF
Linux Debian Ubuntu Discussion Magazine I Unreleased Added Changed Fixed Removed Security Deprecated""".split())
bad = []
for f in sys.argv[1:]:
    if not f.endswith(".md"): continue
    for n, line in enumerate(open(f), 1):
        m = re.match(r"#{1,6} (.+)", line)
        if not m or re.match(r"\[\d", m.group(1)): continue  # skip changelog version headings
        words = re.findall(r"[A-Za-z][\w;.'-]*", m.group(1))[1:]
        caps = [w for w in words if w[0].isupper() and w not in keep and not w.isupper()]
        if caps: bad.append(f"        {f}:{n}: {line.strip()}  ({', '.join(caps)})")
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
EOF

echo "== docs hold together"
check "relative links and README anchors resolve" python3 - "${DOCS[@]}" <<'EOF'
import os, re, sys
def slug(h): return re.sub(r"[^\w\- ]", "", h.strip().lower()).replace(" ", "-")
anchors = {}
for f in sys.argv[1:]:
    if f.endswith(".md"):
        anchors[f] = {slug(m) for m in re.findall(r"^#{1,6} (.+)$", open(f).read(), re.M)}
bad = []
for f in anchors:
    for target in re.findall(r"\]\(([^)\s]+)\)|href=\"([^\"]+)\"", open(f).read()):
        t = target[0] or target[1]
        if re.match(r"[a-z]+:", t): continue
        path, _, frag = t.partition("#")
        p = os.path.normpath(os.path.join(os.path.dirname(f), path)) if path else f
        if not os.path.exists(p): bad.append(f"        {f}: missing {t}")
        elif frag and p in anchors and frag not in anchors[p]: bad.append(f"        {f}: no heading for #{frag}")
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
EOF
check "CHANGELOG has an Unreleased section" grep -q '^## \[Unreleased\]' CHANGELOG.md
check "README install line lists every tool the script needs" \
  bash -c 'for p in curl gnupg2 binutils tar; do grep -q "^sudo dnf install .*\<$p\>" README.md || exit 1; done'
check "every command in the usage line is in README's command table" \
  bash -c 'for c in install update auto-update doctor cowork uninstall version; do grep -q "^| \`$c" README.md || grep -q "\`$c\`" README.md || exit 1; done'

echo
if [ "$failed" != 0 ]; then echo "FAIL ($failed of $((pass + failed)) checks)"; exit 1; fi
echo "PASS ($pass checks)"
