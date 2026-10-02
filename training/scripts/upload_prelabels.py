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
import time
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


def with_backoff(fn, *a, **kw):
    """Roboflow answers bursts with "Too Many Requests"; wait and retry instead of stopping
    between the annotation save and the tag (a rerun would then skip the image as already annotated)."""
    for attempt in range(8):
        try:
            return fn(*a, **kw)
        except Exception as e:
            if "Too Many Requests" not in str(e) or attempt == 7:
                raise
            wait = 5 * 2 ** attempt
            print(f"  rate-limited; waiting {wait}s", flush=True)
            time.sleep(wait)


def is_our_draft(key: str, image_id: str, boxes, classes: list[str]) -> bool:
    """True if the image's saved annotation is exactly this draft (a run stopped after saving it)."""
    import requests

    def get():
        r = requests.get(f"https://api.roboflow.com/{WORKSPACE}/{PROJECT}/images/{image_id}",
                         params={"api_key": key}, timeout=60)
        r.raise_for_status()  # a 429 raises "Too Many Requests", which with_backoff retries
        return r.json()
    ann = (with_backoff(get).get("image") or {}).get("annotation") or {}
    return sorted(b["label"] for b in ann.get("boxes", [])) == sorted(classes[b[0]] for b in boxes)


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
    # Log lines: "<name>\t<status>". status: sent (ours, not tagged yet), tagged, skipped (someone else's).
    # Older lines without a status were tagged one by one.
    log = args.prelabeled / "uploaded.txt"
    status = {}
    for line in (log.read_text().splitlines() if log.exists() else []):
        name, _, st = line.partition("\t")
        status[name] = st or "tagged"

    sent, skipped, missing = 0, 0, []
    with open(log, "a") as fh:
        for lbl, boxes in drafted[: args.limit] if args.limit else drafted:
            img = images[lbl.stem]
            if img is None or img.name not in matched:
                missing.append(lbl.stem)
                continue
            rid = matched[img.name]["id"]
            if img.name in status or args.dry_run:
                continue
            with Image.open(img) as im:
                size = im.size
            r = with_backoff(rfapi.save_annotation, key, PROJECT, f"{lbl.stem}.xml",
                             voc_xml(img.name, size, boxes, classes), rid,
                             job_name=args.tag, overwrite=False, add_to_dataset=False)
            st = "sent"
            if r.get("warn") == "already annotated" and not is_our_draft(key, rid, boxes, classes):
                st = "skipped"  # someone else's annotation; don't mark it as a draft
            sent, skipped = sent + (st == "sent"), skipped + (st == "skipped")
            status[img.name] = st
            fh.write(f"{img.name}\t{st}\n")
            fh.flush()
            time.sleep(0.5)
            if (sent + skipped) % 50 == 0:
                print(f"  {sent + skipped} done", flush=True)
    print(f"uploaded {sent} drafts, {skipped} already annotated (left alone), {len(missing)} not found in Roboflow"
          + (" [dry run]" if args.dry_run else ""))
    if missing:
        print("  not found:", missing[:10])

    # Tag in bulk (one call per 500 images) rather than one call per image.
    to_tag = [n for n, st in status.items() if st == "sent" and n in matched]
    if to_tag and not args.dry_run:
        for i in range(0, len(to_tag), 500):
            chunk = to_tag[i:i + 500]
            with_backoff(rfapi.batch_update_image_metadata, key, WORKSPACE,
                         [{"imageId": matched[n]["id"], "addTags": [args.tag]} for n in chunk])
        with open(log, "a") as fh:
            fh.writelines(f"{n}\ttagged\n" for n in to_tag)
        print(f"tagged {len(to_tag)} images {args.tag} (applied asynchronously by Roboflow)")


if __name__ == "__main__":
    main()
