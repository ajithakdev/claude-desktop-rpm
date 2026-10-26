#!/usr/bin/env python3
"""Draw the README stats card: stars over time and script downloads per release.

GitHub keeps the date of every star but only a running total of downloads, so
downloads are shown per release. Writes stats-light.svg and stats-dark.svg into
the directory given as the first argument. Uses GITHUB_TOKEN if set.
"""
import datetime as dt
import html
import json
import os
import sys
import urllib.request

REPO = os.environ.get("GITHUB_REPOSITORY", "ajithakdev/claude-desktop-rpm")
ASSET = "claude-desktop-rpm.sh"
THEMES = {
    "light": dict(bg="#ffffff", border="#d0d7de", fg="#1f2328", dim="#59636e", grid="#eaeef2", star="#bf8700", bar="#0969da"),
    "dark": dict(bg="#0d1117", border="#30363d", fg="#e6edf3", dim="#9198a1", grid="#21262d", star="#e3b341", bar="#4493f8"),
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


def card(t, stars, releases, start, today):
    W, H = 660, 190
    span = max((today - start).days, 1)
    total_dl = sum(n for _, _, n in releases)
    e = html.escape
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" '
        f'aria-label="{len(stars)} stars and {total_dl} script downloads since {start}">',
        f'<rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="10" fill="{t["bg"]}" stroke="{t["border"]}"/>',
        '<g font-family="-apple-system, Segoe UI, Cantarell, Noto Sans, Helvetica, Arial, sans-serif">',
    ]
    # Each panel: title and total, then a chart in a 270x96 box.
    for x0, title, total, color in ((24, "Stars", len(stars), t["star"]), (354, "Script downloads", total_dl, t["bar"])):
        out.append(f'<text x="{x0}" y="34" font-size="13" fill="{t["dim"]}">{title}</text>')
        out.append(f'<text x="{x0}" y="62" font-size="26" font-weight="600" fill="{t["fg"]}">{total}</text>')
        out.append(f'<line x1="{x0}" y1="168" x2="{x0 + 270}" y2="168" stroke="{t["grid"]}"/>')
    # Stars: a step line of the running count, from the first release to today.
    top = max(len(stars), 1)
    pts, n = [(24, 168)], 0
    for d in sorted(stars):
        x = 24 + 270 * (d - start).days / span
        pts += [(x, 168 - 92 * n / top)]
        n += 1
        pts += [(x, 168 - 92 * n / top)]
    pts.append((294, 168 - 92 * n / top))
    out.append(f'<polyline points="{" ".join(f"{x:.1f},{y:.1f}" for x, y in pts)}" fill="none" stroke="{t["star"]}" stroke-width="2.5" stroke-linejoin="round"/>')
    # Downloads: one bar per release, newest eight, labelled with the tag.
    shown = releases[-8:]
    most = max([n for _, _, n in shown] + [1])
    slot = 270 / max(len(shown), 1)
    for i, (tag, _, n) in enumerate(shown):
        h = max(92 * n / most, 1.5)
        x = 354 + i * slot + slot * 0.18
        out.append(f'<rect x="{x:.1f}" y="{168 - h:.1f}" width="{slot * 0.64:.1f}" height="{h:.1f}" rx="2" fill="{t["bar"]}"><title>{e(tag)}: {n}</title></rect>')
        out.append(f'<text x="{x + slot * 0.32:.1f}" y="{162 - h:.1f}" font-size="11" text-anchor="middle" fill="{t["dim"]}">{n}</text>')
        out.append(f'<text x="{x + slot * 0.32:.1f}" y="182" font-size="10" text-anchor="middle" fill="{t["dim"]}">{e(tag)}</text>')
    out.append(f'<text x="24" y="182" font-size="10" fill="{t["dim"]}">{start} to {today}</text>')
    out += ["</g>", "</svg>"]
    return "\n".join(out) + "\n"


def main():
    outdir = sys.argv[1] if len(sys.argv) > 1 else "."
    stars = [day(s["starred_at"]) for s in get("stargazers", "application/vnd.github.star+json")]
    rels = sorted(
        (day(r["published_at"]), r["tag_name"], sum(a["download_count"] for a in r["assets"] if a["name"] == ASSET))
        for r in get("releases") if not r["draft"]
    )
    releases = [(tag, d, n) for d, tag, n in rels]
    today = dt.date.today()
    start = min([d for _, d, _ in releases] + stars + [today])
    for name, t in THEMES.items():
        with open(os.path.join(outdir, f"stats-{name}.svg"), "w") as f:
            f.write(card(t, stars, releases, start, today))
    print(f"{len(stars)} stars, {sum(n for *_, n in releases)} script downloads over {len(releases)} releases")


if __name__ == "__main__":
    main()
