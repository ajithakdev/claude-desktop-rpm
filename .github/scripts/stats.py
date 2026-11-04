#!/usr/bin/env python3
"""Draw the README cards: stars and downloads, and the latest release.

GitHub keeps the date of every star but only a running total of downloads, so
each run appends today's total to history.json and the daily download bars come
from the differences. Reads and writes history.json, and writes stats-*.svg,
release-*.svg (light and dark) and avatar-*.svg for the Credits in the directory given as the first argument.
Uses GITHUB_TOKEN if set.
"""
import datetime as dt
import base64
import html
import json
import os
import sys
import urllib.request

REPO = os.environ.get("GITHUB_REPOSITORY", "ajithakdev/claude-desktop-rpm")
ASSET = "claude-desktop-rpm.sh"
# Anthropic's package list, read only to show the newest app version on the card.
PACKAGES = "https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages"
# Desktops someone has run the script on; add one when a test report comes in.
TESTED = ["Fedora 44 GNOME", "KDE Plasma 6.7", "Fedora Atomic (Aurora)"]
CHECKS = ["Signed index", "SHA256 checked", "No root", "Unmodified app"]
# People in the README Credits, drawn as round avatars from their current profile picture.
# Fedora Discussion avatar URLs change with the picture, so they are looked up each run.
CREDITS = {
    "aurora": ("Harald Lapp", "https://github.com/aurora.png?size=128"),
    "thephatlee": ("Marko Jokinen", "fedora"),
    "glb": ("Gregory Lee Bartholomew", "fedora"),
    "rlengland": ("Richard England", "fedora"),
    "jflory7": ("Justin Wheeler", "fedora"),
}
FEDORA = "https://discussion.fedoraproject.org"
ICON = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "images", "icon-96.png")
THEMES = {
    "light": dict(bg="#ffffff", border="#d0d7de", fg="#1f2328", dim="#59636e", grid="#eaeef2", star="#bf8700", bar="#0969da", chip="#f6f8fa", ok="#1a7f37", down="#cf222e", cur="#e5534b", last="#f4b7b3"),
    "dark": dict(bg="#0d1117", border="#30363d", fg="#e6edf3", dim="#9198a1", grid="#21262d", star="#e3b341", bar="#4493f8", chip="#161b22", ok="#3fb950", down="#f85149", cur="#f47067", last="#6e3330"),
}


def get(path, accept="application/vnd.github+json"):
    items, url = [], f"https://api.github.com/repos/{REPO}/{path}?per_page=100"
    while url:
        req = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "stats-card"})
        if os.environ.get("GITHUB_TOKEN"):
            req.add_header("Authorization", f"Bearer {os.environ['GITHUB_TOKEN']}")
        with urllib.request.urlopen(req, timeout=30) as r:
            items += json.load(r)
            url = next((p.split(";")[0].strip("<> ") for p in r.headers.get("Link", "").split(",") if 'rel="next"' in p), None)
    return items


def day(s):
    return dt.date.fromisoformat(s[:10])


DAYS = 28  # bars on the card: the current 14 days and the 14 before them


def card(t, panels, today):
    """Two panels of daily bars, each with a total and the change on the previous 14 days."""
    W, H = 660, 210
    e = html.escape
    first = today - dt.timedelta(days=DAYS - 1)
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" '
        f'aria-label="{e(", ".join(f"{total} {title.lower()}" for title, total, _, _ in panels))}">',
        f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="10" fill="{t["bg"]}" stroke="{t["border"]}"/>',
        '<g font-family="-apple-system, Segoe UI, Cantarell, Noto Sans, Helvetica, Arial, sans-serif">',
    ]
    for x0, (title, total, daily, note) in zip((24, 354), panels):
        cur = sum(daily.get(first + dt.timedelta(days=i), 0) for i in range(14, DAYS))
        prev = sum(daily.get(first + dt.timedelta(days=i), 0) for i in range(14))
        if note:
            change, color = note, t["dim"]
        elif prev:
            pct = round(100 * (cur - prev) / prev)
            change, color = f'{"↑" if pct >= 0 else "↓"}{abs(pct)}%', t["ok"] if pct >= 0 else t["down"]
        else:
            change, color = f"+{cur} in 14 days", t["ok"] if cur else t["dim"]
        out.append(f'<text x="{x0}" y="30" font-size="13" font-weight="600" fill="{t["dim"]}">{e(title)}</text>')
        out.append(f'<text x="{x0}" y="60" font-size="26" font-weight="600" fill="{t["fg"]}">{total}</text>')
        out.append(f'<text x="{x0 + 18 + 16 * len(str(total))}" y="58" font-size="12" font-weight="600" fill="{color}">{e(change)}</text>')
        # Legend, then a bar per day over 28 days; the older half is drawn faded.
        for dx, name, c in ((0, "Current 14 days", t["cur"]), (118, "14 days before", t["last"])):
            out.append(f'<rect x="{x0 + dx}" y="72" width="10" height="8" rx="2" fill="{c}"/>')
            out.append(f'<text x="{x0 + dx + 14}" y="80" font-size="10" fill="{t["dim"]}">{name}</text>')
        most = max([daily.get(first + dt.timedelta(days=i), 0) for i in range(DAYS)] + [1])
        out.append(f'<text x="{x0 + 278}" y="98" font-size="9" text-anchor="end" fill="{t["dim"]}">{most}</text>')
        for y in (100, 140):
            out.append(f'<line x1="{x0}" y1="{y}" x2="{x0 + 282}" y2="{y}" stroke="{t["grid"]}" stroke-dasharray="2 3"/>')
        out.append(f'<line x1="{x0}" y1="180" x2="{x0 + 282}" y2="180" stroke="{t["grid"]}"/>')
        slot = 282 / DAYS
        for i in range(DAYS):
            d = first + dt.timedelta(days=i)
            n = daily.get(d, 0)
            if n:
                h = max(80 * n / most, 2)
                out.append(f'<rect x="{x0 + i * slot + 1:.1f}" y="{180 - h:.1f}" width="{slot - 2:.1f}" height="{h:.1f}" rx="1.5" '
                           f'fill="{t["cur"] if i >= 14 else t["last"]}"><title>{d}: {n}</title></rect>')
        for i in (0, 14, DAYS - 1):
            d = first + dt.timedelta(days=i)
            anchor = "start" if i == 0 else "end" if i == DAYS - 1 else "middle"
            out.append(f'<text x="{x0 + i * slot + (slot if i == DAYS - 1 else 0):.1f}" y="196" font-size="10" text-anchor="{anchor}" fill="{t["dim"]}">{d}</text>')
    out += ["</g>", "</svg>"]
    return "\n".join(out) + "\n"


def daily_downloads(history):
    """Downloads per day from the running totals in history.json."""
    days = sorted(history)
    return {dt.date.fromisoformat(b): max(history[b] - history[a], 0) for a, b in zip(days, days[1:])}


def app_version():
    """Newest claude-desktop version in Anthropic's repo, or None if it can't be read."""
    try:
        req = urllib.request.Request(PACKAGES, headers={"User-Agent": "stats-card"})
        with urllib.request.urlopen(req, timeout=30) as r:
            text = r.read().decode()
    except OSError:
        return None
    vers = [b.split("Version: ", 1)[1].split("\n", 1)[0] for b in text.split("\n\n") if "Package: claude-desktop\n" in b and "Version: " in b]
    return max(vers, key=lambda v: [int(x) if x.isdigit() else 0 for x in v.replace("-", ".").split(".")], default=None)


def release_card(t, tag, date, downloads, app, icon):
    W, H = 660, 196
    e = html.escape
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" '
        f'aria-label="Latest release {e(tag)}, {date}">',
        f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="10" fill="{t["bg"]}" stroke="{t["border"]}"/>',
        f'<rect x="0" y="12" width="4" height="{H - 24}" rx="2" fill="{t["bar"]}"/>',
        '<g font-family="-apple-system, Segoe UI, Cantarell, Noto Sans, Helvetica, Arial, sans-serif">',
        f'<text x="24" y="40" font-size="22" font-weight="600" fill="{t["bar"]}">claude-desktop-rpm {e(tag)}</text>',
        f'<text x="24" y="62" font-size="12" fill="{t["dim"]}">Released {date.strftime("%B %-d, %Y")} · {downloads} downloads so far</text>',
    ]
    if icon:
        out.append(f'<image x="{W - 88}" y="16" width="64" height="64" href="data:image/png;base64,{icon}"/>')

    # A row of rounded chips after a small label, like a release's package list.
    def chips(y, label, items, mark=""):
        x = 24
        if label:
            out.append(f'<text x="{x}" y="{y + 15}" font-size="10" fill="{t["dim"]}">{label}</text>')
            x = 90
        for it in items:
            w = 6.6 * len(it + mark) + 18
            out.append(f'<rect x="{x}" y="{y}" width="{w:.0f}" height="22" rx="5" fill="{t["chip"]}" stroke="{t["border"]}"/>')
            out.append(f'<text x="{x + 9}" y="{y + 15}" font-size="11" fill="{t["fg"]}">{e(it)}'
                       + (f'<tspan dx="4" fill="{t["ok"]}">{mark}</tspan>' if mark else "") + "</text>")
            x += w + 6

    chips(80, "App", [f"Claude Desktop {app}" if app else "Claude Desktop (newest)", "x86_64", "~/.local"])
    chips(110, "Tested on", TESTED, "✓")
    chips(140, "Checks", CHECKS)
    out.append(f'<line x1="24" y1="174" x2="{W - 24}" y2="174" stroke="{t["grid"]}"/>')
    out.append(f'<text x="24" y="188" font-size="10" fill="{t["dim"]}">Script, SHA256SUMS and notes on the Releases page</text>')
    out.append(f'<text x="{W - 24}" y="188" font-size="10" text-anchor="end" fill="{t["dim"]}">App version: newest in Anthropic\'s repository today</text>')
    out += ["</g>", "</svg>"]
    return "\n".join(out) + "\n"


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "stats-card"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read(), r.headers.get_content_type()


def avatar(user, name, url):
    """A round 128px avatar; initials in a circle if the picture can't be fetched."""
    head = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">'
    try:
        if url == "fedora":
            info = json.loads(fetch(f"{FEDORA}/u/{user}.json")[0])
            url = FEDORA + info["user"]["avatar_template"].replace("{size}", "128")
        data, mime = fetch(url)
        if not mime.startswith("image/"):
            raise ValueError(mime)
    except (OSError, ValueError, KeyError) as err:
        print(f"avatar {user}: {err}", file=sys.stderr)
        initials = html.escape("".join(w[0] for w in name.split()[:2]))
        return (head + '<circle cx="64" cy="64" r="64" fill="#8c959f"/><text x="64" y="78" font-size="40" text-anchor="middle" '
                f'fill="#ffffff" font-family="Noto Sans, Helvetica, Arial, sans-serif">{initials}</text></svg>\n')
    b64 = base64.b64encode(data).decode()
    return (head + '<defs><clipPath id="c"><circle cx="64" cy="64" r="64"/></clipPath></defs>'
            f'<image width="128" height="128" preserveAspectRatio="xMidYMid slice" clip-path="url(#c)" href="data:{mime};base64,{b64}"/></svg>\n')


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    stars = [day(s["starred_at"]) for s in get("stargazers", "application/vnd.github.star+json")]
    rels = sorted(
        (day(r["published_at"]), r["tag_name"], sum(a["download_count"] for a in r["assets"] if a["name"] == ASSET))
        for r in get("releases") if not r["draft"]
    )
    releases = [(tag, d, n) for d, tag, n in rels]
    today = dt.date.today()
    total_dl = sum(n for *_, n in releases)
    hist_path = os.path.join(outdir, "history.json")
    try:
        with open(hist_path) as f:
            history = json.load(f)
    except FileNotFoundError:
        history = {}
    history[today.isoformat()] = total_dl
    with open(hist_path, "w") as f:
        json.dump(history, f, indent=0, sort_keys=True)
    star_days = {}
    for d in stars:
        star_days[d] = star_days.get(d, 0) + 1
    since = min(history)
    note = f"daily since {since}" if dt.date.fromisoformat(since) > today - dt.timedelta(days=DAYS - 1) else ""
    panels = [("New stars", len(stars), star_days, ""), ("Script downloads", total_dl, daily_downloads(history), note)]
    for name, t in THEMES.items():
        with open(os.path.join(outdir, f"stats-{name}.svg"), "w") as f:
            f.write(card(t, panels, today))
    for user, (name, url) in CREDITS.items():
        with open(os.path.join(outdir, f"avatar-{user}.svg"), "w") as f:
            f.write(avatar(user, name, url))
    app = app_version()
    try:
        with open(ICON, "rb") as f:
            icon = base64.b64encode(f.read()).decode()
    except OSError:
        icon = None
    if releases:
        tag, date, n = releases[-1]
        for name, t in THEMES.items():
            with open(os.path.join(outdir, f"release-{name}.svg"), "w") as f:
                f.write(release_card(t, tag, date, n, app, icon))
    print(f"{len(stars)} stars, {total_dl} script downloads over {len(releases)} releases, app {app}")


if __name__ == "__main__":
    main()
