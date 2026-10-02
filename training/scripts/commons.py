"""Collect storm-damage photos from Wikimedia Commons (FEMA, NWS, and others), with licenses.

FEMA's own site blocks automated downloads, but many FEMA/NWS photos are mirrored on Commons,
which records each file's license, author, and event category.

    # 1. Crawl categories → manifest (no images yet). Each photo's "event" is the category it came from.
    python scripts/commons.py crawl "Category:Tornado damage" --out manifests/tornado.jsonl
    # 2. See events and counts, to pick held-out test events.
    python scripts/commons.py events manifests/tornado.jsonl
    # 3. Download (1280px wide) into a source folder, filtered by event.
    python scripts/commons.py download manifests/tornado.jsonl fema_tornado_test --events "2013 Moore tornado damage" ...
    python scripts/commons.py download manifests/tornado.jsonl fema_pool --exclude-events-of fema_tornado_test

Each source folder gets attribution.csv (title, author, license, page URL), required for CC BY / BY-SA.
Only licenses without NC/ND are kept. Black-and-white/pre-1990 categories are skipped.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

from common import RAW_DIR, TRAINING_DIR

API = "https://commons.wikimedia.org/w/api.php"
HEADERS = {"User-Agent": "DebrisMapper/0.1 (open-source storm debris detector; https://github.com/apandji/debris-detection)"}
OLD = re.compile(r"\b(1[0-8]\d\d|19[0-8]\d)\b")  # skip historic (mostly B&W) categories
SKIP = re.compile(r"(?i)\b(scale|diagram|map|radar|satellite|aerial|video|stereoscopic|track|path|funnel|waterspout|storm chas\w*)\b"
                  r"|^Category:E?F\d tornadoes$")  # rating categories hold funnel photos, not damage


def api(**params) -> dict:
    params["format"] = "json"
    req = urllib.request.Request(f"{API}?{urllib.parse.urlencode(params)}", headers=HEADERS)
    for attempt in range(12):
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                time.sleep(1.0)  # be polite to Commons
                return json.load(r)
        except Exception as e:
            err = e
            retry = getattr(e, "headers", None) and e.headers.get("Retry-After")
            time.sleep(min(120, int(retry) if retry and retry.isdigit() else 3 * 2 ** attempt))
    raise RuntimeError(f"Commons API failed ({err}): {params}")


def fetch_bytes(url: str, tries: int = 3) -> bytes:
    """GET with short backoff. Commons 429s some files for minutes; give up on those and let a re-run retry them."""
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=HEADERS), timeout=60) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == tries - 1:
                raise
            wait = min(60, int(e.headers.get("Retry-After") or 0) or 5 * 2 ** attempt)
        except (urllib.error.URLError, TimeoutError):
            if attempt == tries - 1:
                raise
            wait = min(300, 5 * 2 ** attempt)
        print(f"  backoff {wait}s ({url.rsplit('/', 1)[-1][:60]})", flush=True)
        time.sleep(wait)


STANDARD_WIDTHS = (500, 960, 1280)  # Wikimedia only serves standard thumbnail sizes; originals are throttled hard
ORIGINAL = re.compile(r"^(https://upload\.wikimedia\.org/wikipedia/commons)/(\w/\w\w)/([^?/]+)")


def standard_thumb(r: dict) -> str:
    """For photos ≤1280 px wide the API hands back the original file, which Wikimedia rate-limits
    (HTTP 429, Retry-After 600). Ask for the largest standard thumbnail narrower than the original."""
    m = ORIGINAL.match(r["thumb_url"])
    widths = [w for w in STANDARD_WIDTHS if w < (r.get("width") or 0)]
    if not m or not widths:
        return r["thumb_url"]
    base, shard, name = m.groups()
    return f"{base}/thumb/{shard}/{name}/{widths[-1]}px-{name}"


def subcats(cat: str) -> list[str]:
    out, cont = [], {}
    while True:
        r = api(action="query", list="categorymembers", cmtitle=cat, cmtype="subcat", cmlimit=500, **cont)
        out += [m["title"] for m in r["query"]["categorymembers"]]
        if "continue" not in r:
            return out
        cont = {"cmcontinue": r["continue"]["cmcontinue"]}


def files_in(cat: str, width: int) -> list[dict]:
    out, cont = [], {}
    while True:
        r = api(action="query", generator="categorymembers", gcmtitle=cat, gcmtype="file", gcmlimit=50,
                prop="imageinfo", iiprop="url|size|mime|extmetadata", iiurlwidth=width, **cont)
        for page in (r.get("query") or {}).get("pages", {}).values():
            info = (page.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata") or {}
            get = lambda k: html.unescape(re.sub(r"<[^>]+>", "", (meta.get(k) or {}).get("value", ""))).strip()
            out.append({
                "title": page["title"],
                "page_url": info.get("descriptionurl"),
                "thumb_url": info.get("thumburl") or info.get("url"),
                "width": info.get("width"), "height": info.get("height"), "mime": info.get("mime"),
                "license": get("LicenseShortName"), "artist": get("Artist"), "credit": get("Credit"),
                "date": get("DateTimeOriginal") or get("DateTime"),
                "event": cat.removeprefix("Category:"),
            })
        if "continue" not in r:
            return out
        cont = {k: v for k, v in r["continue"].items()}
        time.sleep(0.2)


def usable(f: dict, min_side: int) -> bool:
    lic = f["license"].upper()
    return (f["mime"] == "image/jpeg" and min(f["width"] or 0, f["height"] or 0) >= min_side
            and lic and "NC" not in lic and "ND" not in lic)


def crawl(args) -> None:
    # Appends as it goes, so a re-run resumes instead of starting over.
    args.out.parent.mkdir(parents=True, exist_ok=True)
    seen_files = {r["title"] for r in load(args.out)} if args.out.exists() else set()
    seen_cats, total = set(), 0
    frontier = [(c, 0) for c in args.categories]
    with open(args.out, "a") as fh:
        while frontier:
            cat, depth = frontier.pop(0)
            if cat in seen_cats or OLD.search(cat) or SKIP.search(cat):
                continue
            seen_cats.add(cat)
            try:
                kept = 0
                for f in files_in(cat, args.width):
                    if f["title"] not in seen_files and usable(f, args.min_side):
                        seen_files.add(f["title"])
                        fh.write(json.dumps(f) + "\n")
                        kept += 1
                fh.flush()
                total += kept
                print(f"{'  ' * depth}{cat}: +{kept}", flush=True)
                if depth < args.depth:
                    frontier += [(c, depth + 1) for c in subcats(cat)]
            except RuntimeError as e:
                print(f"{'  ' * depth}{cat}: FAILED, skipped ({e})", flush=True)
    print(f"\n+{total} usable photos ({len(seen_files)} total) from {len(seen_cats)} categories → {args.out}")


def load(path: Path) -> list[dict]:
    return [json.loads(line) for line in open(path)]


def events(args) -> None:
    rows = load(args.manifest)
    for ev, n in Counter(r["event"] for r in rows).most_common():
        lic = Counter(r["license"] for r in rows if r["event"] == ev).most_common(2)
        print(f"{n:5d}  {ev}   [{', '.join(f'{l} {c}' for l, c in lic)}]")


def download(args) -> None:
    rows = load(args.manifest)
    if args.events:
        rows = [r for r in rows if r["event"] in set(args.events)]
    if args.exclude_events_of:
        # A fresh checkout has no data/raw/<id>/, so fall back to the committed copy. Never run
        # with an empty exclude set: that would pull held-out test events into the pool.
        attr = RAW_DIR / args.exclude_events_of / "attribution.csv"
        if not attr.exists():
            attr = TRAINING_DIR / "manifests" / f"{args.exclude_events_of}_attribution.csv"
        held = {r["event"] for r in csv.DictReader(open(attr))} if attr.exists() else set()
        if not held:
            raise SystemExit(f"No events found for --exclude-events-of {args.exclude_events_of}; refusing to download.")
        print(f"Excluding {len(held)} events of {args.exclude_events_of}: {sorted(held)}")
        rows = [r for r in rows if r["event"] not in held]
    if args.exclude_events:
        rows = [r for r in rows if r["event"] not in set(args.exclude_events)]
    rows = rows[: args.limit] if args.limit else rows

    dest = RAW_DIR / args.source / "images"
    dest.mkdir(parents=True, exist_ok=True)
    attr_path = RAW_DIR / args.source / "attribution.csv"
    existing = {r["file"]: r["title"] for r in csv.DictReader(open(attr_path))} if attr_path.exists() else {}
    with open(attr_path, "a", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["file", "title", "event", "license", "artist", "credit", "date", "page_url"])
        if not existing:
            w.writeheader()
        n = 0
        for r in rows:
            name = re.sub(r"[^\w.-]+", "_", r["title"].removeprefix("File:"))[:150]
            if not name.lower().endswith((".jpg", ".jpeg")):
                name += ".jpg"
            if existing.get(name, r["title"]) != r["title"]:
                # Long titles that share a 150-char prefix would overwrite each other's file.
                name = f"{name[:140].removesuffix('.jpg')}_{hashlib.sha1(r['title'].encode()).hexdigest()[:8]}.jpg"
            if name in existing:
                continue
            try:
                (dest / name).write_bytes(fetch_bytes(standard_thumb(r)))
            except Exception as e:
                print(f"  skip {r['title']}: {e}")
                continue
            w.writerow({"file": name, **{k: r.get(k, "") for k in w.fieldnames if k != "file"}})
            existing[name] = r["title"]
            fh.flush()
            n += 1
            time.sleep(args.delay)
    print(f"Downloaded {n} photos → {dest}  (attribution: {attr_path})")


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("crawl")
    c.add_argument("categories", nargs="+")
    c.add_argument("--out", type=Path, required=True)
    c.add_argument("--depth", type=int, default=3)
    c.add_argument("--width", type=int, default=1280)
    c.add_argument("--min-side", type=int, default=600)
    c.set_defaults(fn=crawl)
    e = sub.add_parser("events")
    e.add_argument("manifest", type=Path)
    e.set_defaults(fn=events)
    d = sub.add_parser("download")
    d.add_argument("manifest", type=Path)
    d.add_argument("source", help="source id in sources.yaml, e.g. fema_tornado_test")
    d.add_argument("--events", nargs="*")
    d.add_argument("--exclude-events", nargs="*")
    d.add_argument("--exclude-events-of", help="skip events already used by this source (keeps test events out)")
    d.add_argument("--limit", type=int)
    d.add_argument("--delay", type=float, default=1.0, help="seconds between downloads (Commons rate-limits)")
    d.set_defaults(fn=download)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
