"""Attach prelabel.py drafts to images already in Roboflow, for human review.

    export ROBOFLOW_API_KEY=...
    python scripts/upload_prelabels.py data/prelabeled/fema_pool --dry-run      # counts only
    python scripts/upload_prelabels.py data/prelabeled/fema_pool                # upload drafts + tag

The pool photos were uploaded earlier (batch `commons-pool`, tag `pool`), so this never uploads
images: it looks each one up by file name and saves the draft as its annotation. Roboflow then
moves each drafted image out of its batch into an annotation job named after --tag
(`prelabel-rubble-v0`), where a person reviews it in Annotate.

Safety:
  - add_to_dataset=False: drafted images stay out of the Dataset, so no version (and no training
    export) includes them until a person reviews and approves them.
  - overwrite=False: an image that already has an annotation (e.g. a human's) is left alone.
  - Only images with at least one `--require-class` draft are sent; every draft box on those
    images goes with them, so the reviewer labels the whole photo.
Resumable: uploaded image names are appended to <prelabeled>/uploaded.txt.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from xml.sax.saxutils import escape

from PIL import Image

from common import load_registry, read_boxes

WORKSPACE, PROJECT = "pandji", "storm-debris-detection"


def list_images(key: str, query: str) -> dict[str, dict]:
    from roboflow.adapters import rfapi
    out, token = {}, None
    while True:
        r = rfapi.workspace_search(key, WORKSPACE, query, page_size=250, fields=["id", "name", "tags"],
                                   continuation_token=token)
        for x in r.get("results", []):
            out[x["name"]] = x
        token = r.get("continuationToken")
        if not token or not r.get("results"):
            return out


def name_key(name: str, strip_hash: bool = False) -> str:
    stem = name.rsplit(".", 1)[0]
    if strip_hash:  # the first upload shortened long names to <prefix>_<8 hex>
        stem = re.sub(r"_[0-9a-f]{8}$", "", stem)
    return re.sub(r"[^a-z0-9]", "", stem.lower())


def match_names(local: list[str], remote: dict[str, dict]) -> dict[str, dict]:
    """Local file name → Roboflow image. The first upload sanitized and shortened names differently,
    so compare alphanumerics only and allow a long shared prefix. Only one-to-one matches are kept;
    anything ambiguous is left out rather than guessed."""
    by_key = defaultdict(list)
    for n in remote:
        by_key[name_key(n, True)].append(n)
    keys = {k: v[0] for k, v in by_key.items() if len(v) == 1}
    out = {}
    for n in local:
        lk = name_key(n)
        if lk in keys:
            out[n] = keys[lk]
            continue
        cands = [k for k in keys if len(k) >= 40 and (lk.startswith(k) or k.startswith(lk))]
        best = [k for k in cands if len(k) == max(map(len, cands))] if cands else []
        if len(best) == 1:
            out[n] = keys[best[0]]
    uses = Counter(out.values())
    return {n: remote[r] for n, r in out.items() if uses[r] == 1}


def voc_xml(name: str, size: tuple[int, int], boxes, classes: list[str]) -> str:
    W, H = size
    objs = "".join(
        f"<object><name>{escape(classes[c])}</name><bndbox>"
        f"<xmin>{max(0, (cx - w / 2) * W):.1f}</xmin><ymin>{max(0, (cy - h / 2) * H):.1f}</ymin>"
        f"<xmax>{min(W, (cx + w / 2) * W):.1f}</xmax><ymax>{min(H, (cy + h / 2) * H):.1f}</ymax>"
        f"</bndbox></object>" for c, cx, cy, w, h in boxes)
    return (f"<annotation><filename>{escape(name)}</filename><size><width>{W}</width><height>{H}</height>"
            f"<depth>3</depth></size>{objs}</annotation>")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("prelabeled", type=Path, help="output dir of prelabel.py")
    ap.add_argument("--require-class", default="rubble_debris", help="only send images with a draft of this class")
    ap.add_argument("--tag", default="prelabel-rubble-v0")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    key = os.environ.get("ROBOFLOW_API_KEY") or sys.exit("Set ROBOFLOW_API_KEY.")
    from roboflow.adapters import rfapi

    classes = load_registry()["classes"]
    want = classes.index(args.require_class)
    labels = sorted((args.prelabeled / "labels").glob("*.txt"))
    drafted = [(lbl, boxes) for lbl, boxes in ((lbl, read_boxes(lbl)) for lbl in labels)
               if any(b[0] == want for b in boxes)]
    print(f"{len(labels)} prelabeled images, {len(drafted)} with a {args.require_class} draft")

    remote = list_images(key, "tag:pool")
    images = {lbl.stem: next((args.prelabeled / "images").glob(lbl.stem + ".*"), None) for lbl, _ in drafted}
    matched = match_names([p.name for p in images.values() if p], remote)
    print(f"{len(remote)} pool images in Roboflow; {len(matched)} of {len(drafted)} drafted images matched by name")
    log = args.prelabeled / "uploaded.txt"
    done = set(log.read_text().split("\n")) if log.exists() else set()

    sent, skipped, missing = 0, 0, []
    with open(log, "a") as fh:
        for lbl, boxes in drafted[: args.limit] if args.limit else drafted:
            img = images[lbl.stem]
            if img is None or img.name not in matched:
                missing.append(lbl.stem)
                continue
            rid = matched[img.name]["id"]
            if img.name in done or args.dry_run:
                continue
            with Image.open(img) as im:
                size = im.size
            r = rfapi.save_annotation(key, PROJECT, f"{lbl.stem}.xml", voc_xml(img.name, size, boxes, classes), rid,
                                      job_name=args.tag, overwrite=False, add_to_dataset=False)
            if r.get("warn") == "already annotated":
                skipped += 1  # someone else's annotation; don't mark it as a draft
            else:
                sent += 1
                rfapi.update_image_metadata(key, WORKSPACE, rid, add_tags=[args.tag])
            fh.write(img.name + "\n")
            fh.flush()
            if (sent + skipped) % 50 == 0:
                print(f"  {sent + skipped} done", flush=True)
    print(f"uploaded {sent} drafts, {skipped} already annotated (left alone), {len(missing)} not found in Roboflow"
          + (" [dry run]" if args.dry_run else ""))
    if missing:
        print("  not found:", missing[:10])


if __name__ == "__main__":
    main()
