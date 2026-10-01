"""Download `kind: roboflow` sources into data/raw/<id>/ (YOLO format).

    export ROBOFLOW_API_KEY=...     # roboflow.com → Settings → API Keys (free account)
    python scripts/fetch.py               # all roboflow sources still at status: todo
    python scripts/fetch.py --only rf_rubble_detection
    python scripts/fetch.py --list        # show every source and what to do next

Manual sources (D-Fire, GDBDA, FEMA, Incidents1M) print their instructions instead.
"""
from __future__ import annotations

import argparse
import os
import sys

from common import load_registry, set_status, source_dir


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

    todo = [s for s in sources if args.force or s["status"] == "todo"]
    rf_sources = [s for s in todo if s["kind"] == "roboflow"]
    for s in todo:
        if s["kind"] != "roboflow":
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
            set_status(s["id"], "downloaded")
            print(f"  ok (v{version}); status → downloaded. Next: python scripts/sheet.py --only {s['id']}")
        except Exception as e:  # keep going; one bad project shouldn't stop the rest
            print(f"  FAILED: {e}")


if __name__ == "__main__":
    main()
