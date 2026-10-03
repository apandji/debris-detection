"""Download `kind: roboflow` sources into data/raw/<id>/ (YOLO format).

    export ROBOFLOW_API_KEY=...     # roboflow.com → Settings → API Keys (free account)
    python scripts/fetch.py               # all roboflow sources still at status: todo
    python scripts/fetch.py --only rf_rubble_detection
    python scripts/fetch.py --list        # show every source and what to do next

Sources with a `download_url` (e.g. D-Fire) are downloaded and unzipped automatically.
Other manual sources (GDBDA, Incidents1M) print their instructions instead.
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import urllib.request
import zipfile

from common import DATA_DIR, load_registry, set_status, source_dir


def fetch_url(s: dict) -> None:
    """Download a zip from `download_url` and unpack it into data/raw/<id>/."""
    dest = source_dir(s)
    tmp = DATA_DIR / "downloads" / f"{s['id']}.zip"
    tmp.parent.mkdir(parents=True, exist_ok=True)
    print(f"\n[url] {s['id']} → {dest} (this can take a while)")
    req = urllib.request.Request(s["download_url"], headers={"User-Agent": "DebrisMapper/0.1"})
    with urllib.request.urlopen(req, timeout=3600) as r, open(tmp, "wb") as fh:
        shutil.copyfileobj(r, fh, length=1 << 22)
    with zipfile.ZipFile(tmp) as z:
        z.extractall(dest)
    tmp.unlink()
    if s["status"] == "todo":
        set_status(s["id"], "downloaded")
    print(f"  ok; status: {s['status'] if s['status'] != 'todo' else 'downloaded'}")


def latest_version(project) -> int:
    nums = []
    for v in project.versions():
        try:
            nums.append(int(str(v.version).rstrip("/").split("/")[-1]))
        except ValueError:
            pass
    if not nums:
        raise RuntimeError("no generated versions; set `version:` in sources.yaml")
    return max(nums)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="source ids")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--force", action="store_true", help="re-download even if not status: todo")
    args = ap.parse_args()

    sources = load_registry()["sources"]
    if args.only:
        sources = [s for s in sources if s["id"] in args.only]

    if args.list:
        for s in sources:
            print(f"{s['status']:<11} {s.get('role', 'train'):<6} {s['kind']:<9} {s['id']}")
        return

    # A fresh checkout has no data/, so anything downloadable that's missing is fetched again
    # (status stays as-is: a re-download of a checked source is still checked).
    downloadable = lambda s: s.get("download_url") or s["kind"] == "roboflow"
    todo = [s for s in sources if s["status"] != "rejected" and (args.force or s["status"] == "todo"
            or (downloadable(s) and not source_dir(s).exists()))]
    rf_sources = [s for s in todo if s["kind"] == "roboflow"]
    for s in todo:
        if s.get("download_url"):
            if source_dir(s).exists() and not args.force:
                print(f"\n[url] {s['id']}: already in {source_dir(s)}")
                continue
            try:
                fetch_url(s)
            except Exception as e:
                print(f"  FAILED: {e}")
        elif s["kind"] == "commons":
            print(f"\n[commons] {s['id']}: python scripts/commons.py download manifests/tornado.jsonl {s['id']} ...")
        elif s["kind"] != "roboflow":
            print(f"\n[manual] {s['id']}: {s['url']}\n  → put files in {source_dir(s)}/")
            if s.get("notes"):
                print(f"  {s['notes'].strip()}")

    if not rf_sources:
        return
    key = os.environ.get("ROBOFLOW_API_KEY")
    if not key:
        sys.exit("Set ROBOFLOW_API_KEY to download Roboflow sources.")
    from roboflow import Roboflow

    rf = Roboflow(api_key=key)
    for s in rf_sources:
        dest = source_dir(s)
        print(f"\n[roboflow] {s['id']} → {dest}")
        try:
            project = rf.workspace(s["workspace"]).project(s["project"])
            version = s.get("version") or latest_version(project)
            project.version(version).download("yolov8", location=str(dest), overwrite=True)
            if s["status"] == "todo":
                set_status(s["id"], "downloaded")
            print(f"  ok (v{version}). Next: python scripts/sheet.py --only {s['id']}")
        except Exception as e:  # keep going; one bad project shouldn't stop the rest
            print(f"  FAILED: {e}")


if __name__ == "__main__":
    main()
