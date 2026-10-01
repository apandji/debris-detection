"""Build one YOLO dataset from every checked source.

    python scripts/merge.py --check                 # class names per source, unmapped names, counts
    python scripts/merge.py                         # write data/merged/ + data.yaml + stats.md
    python scripts/merge.py --include-downloaded    # quick test before sources are eyeballed

What it does, per source in sources.yaml:
  1. Remap each box's class via `class_map` (null drops it; names equal to our classes pass through).
  2. Skip images whose boxes were all dropped (they may still contain unlabeled objects).
     Keep label-less images as negatives only if `negatives: true` (up to `negative_cap`).
  3. Sample at most `cap` positive images.
  4. Drop near-exact duplicates (perceptual hash). Test sources go first, so a training
     copy of a test photo is the one removed — no leakage.
  5. role: test → test split. Everything else → train/val (random --val-frac).
"""
from __future__ import annotations

import argparse
import random
import shutil
from collections import Counter, defaultdict
from pathlib import Path

import yaml
from PIL import Image

from common import DATA_DIR, class_names, find_pairs, load_registry, read_boxes, source_dir

try:
    import imagehash
except ImportError:  # dedup is optional
    imagehash = None

MISSING = object()


def map_class(name: str, class_map: dict, classes: list[str]):
    if name in class_map:
        return class_map[name]
    if name in classes:
        return name
    return MISSING


def collect(source: dict, classes: list[str], rng: random.Random):
    """Returns (kept items, stats). Item = (image, [(cls_idx, cx, cy, w, h)])."""
    root = source_dir(source)
    names = class_names(source, root)
    cmap = source.get("class_map") or {}
    stats = {"unmapped": Counter(), "boxes": Counter(), "images": 0, "negatives": 0,
             "skipped_all_dropped": 0, "names": names, "missing_labels": 0}
    positives, negatives = [], []
    for img, lbl in find_pairs(root):
        if lbl is None:
            stats["missing_labels"] += 1
        raw = read_boxes(lbl)
        if not raw:
            negatives.append((img, []))
            continue
        kept = []
        for cls, cx, cy, w, h in raw:
            name = names[cls] if cls < len(names) else f"<id {cls}>"
            target = map_class(name, cmap, classes)
            if target is MISSING:
                stats["unmapped"][name] += 1
            elif target is not None:
                kept.append((classes.index(target), cx, cy, w, h))
        if kept:
            positives.append((img, kept))
        else:
            stats["skipped_all_dropped"] += 1

    rng.shuffle(positives)
    positives = positives[: source.get("cap") or len(positives)]
    if source.get("negatives"):
        rng.shuffle(negatives)
        negatives = negatives[: source.get("negative_cap") or len(negatives)]
    else:
        negatives = []
    for _, boxes in positives:
        for b in boxes:
            stats["boxes"][classes[b[0]]] += 1
    stats["images"], stats["negatives"] = len(positives), len(negatives)
    return positives + negatives, stats


def phash(path: Path):
    try:
        with Image.open(path) as im:
            return str(imagehash.phash(im))
    except Exception:
        return None


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="report only; write nothing")
    ap.add_argument("--include-downloaded", action="store_true")
    ap.add_argument("--val-frac", type=float, default=0.1)
    ap.add_argument("--seed", type=int, default=0)
    ap.add_argument("--out", type=Path, default=DATA_DIR / "merged")
    ap.add_argument("--link", action="store_true", help="symlink images instead of copying")
    args = ap.parse_args()

    reg = load_registry()
    classes = reg["classes"]
    ok = {"checked"} | ({"downloaded"} if args.include_downloaded else set())
    sources = [s for s in reg["sources"]
               if s.get("role", "train") in ("train", "test") and s["status"] in ok
               and source_dir(s).exists()]
    # Test sources first so dedup removes the training copy, never the test copy.
    sources.sort(key=lambda s: s.get("role", "train") != "test")
    if not sources:
        print(f"No sources with status {sorted(ok)} and files in data/raw/. Run fetch.py, then mark them checked.")
        return

    rng = random.Random(args.seed)
    per_source = {}
    for s in sources:
        items, stats = collect(s, classes, rng)
        per_source[s["id"]] = (s, items, stats)
        print(f"\n{s['id']}  ({s.get('role', 'train')})")
        print(f"  source classes: {stats['names'] or '— none found (set names: in sources.yaml)'}")
        print(f"  kept: {stats['images']} images, {stats['negatives']} negatives; boxes {dict(stats['boxes'])}")
        if stats["unmapped"]:
            print(f"  UNMAPPED (dropped): {dict(stats['unmapped'])}  → add to class_map")
        if stats["skipped_all_dropped"]:
            print(f"  skipped {stats['skipped_all_dropped']} images whose boxes were all dropped")
    if args.check:
        return

    if args.out.exists():
        shutil.rmtree(args.out)
    seen, dupes = set(), Counter()
    split_counts = defaultdict(Counter)
    for sid, (s, items, stats) in per_source.items():
        role = s.get("role", "train")
        for img, boxes in items:
            if imagehash:
                h = phash(img)
                if h in seen:
                    dupes[sid] += 1
                    continue
                if h:
                    seen.add(h)
            split = "test" if role == "test" else ("val" if rng.random() < args.val_frac else "train")
            stem = f"{sid}__{img.stem}"
            dst_img = args.out / "images" / split / f"{stem}{img.suffix.lower()}"
            dst_lbl = args.out / "labels" / split / f"{stem}.txt"
            dst_img.parent.mkdir(parents=True, exist_ok=True)
            dst_lbl.parent.mkdir(parents=True, exist_ok=True)
            if args.link:
                dst_img.symlink_to(img.resolve())
            else:
                shutil.copy2(img, dst_img)
            dst_lbl.write_text("".join(f"{c} {cx:.6f} {cy:.6f} {w:.6f} {h:.6f}\n" for c, cx, cy, w, h in boxes))
            split_counts[split]["images"] += 1
            for c, *_ in boxes:
                split_counts[split][classes[c]] += 1

    data = {"path": str(args.out.resolve()), "train": "images/train", "val": "images/val",
            "names": dict(enumerate(classes))}
    if split_counts["test"]["images"]:
        data["test"] = "images/test"
    (args.out / "data.yaml").write_text(yaml.safe_dump(data, sort_keys=False))

    lines = ["# Merged dataset stats", "", "| source | role | images | negatives | dupes removed | " +
             " | ".join(classes) + " |", "|---" * (5 + len(classes)) + "|"]
    for sid, (s, _, st) in per_source.items():
        lines.append(f"| {sid} | {s.get('role', 'train')} | {st['images']} | {st['negatives']} | {dupes[sid]} | " +
                     " | ".join(str(st["boxes"][c]) for c in classes) + " |")
    lines += ["", "| split | images | " + " | ".join(classes) + " |", "|---" * (2 + len(classes)) + "|"]
    for split in ("train", "val", "test"):
        sc = split_counts[split]
        lines.append(f"| {split} | {sc['images']} | " + " | ".join(str(sc[c]) for c in classes) + " |")
    if not imagehash:
        lines += ["", "_imagehash not installed: duplicates were not removed._"]
    (args.out / "stats.md").write_text("\n".join(lines) + "\n")
    print(f"\nWrote {args.out}/data.yaml and stats.md")
    print("\n".join(lines[-5:]))


if __name__ == "__main__":
    main()
