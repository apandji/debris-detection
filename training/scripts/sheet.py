"""Contact sheet for eyeballing a source before we trust it.

    python scripts/sheet.py --only rf_fallen_trees_origin      # → data/sheets/<id>/index.html
    python scripts/sheet.py                                     # every downloaded source

Draws each image's boxes with the source's own class names. Look for:
ground-level (not drone/satellite), storm-relevant, sensible boxes, no duplicates/watermarks.
If it passes, set `status: checked` in sources.yaml and fill any unmapped classes.
"""
from __future__ import annotations

import argparse
import html
import random

from PIL import Image, ImageDraw

from common import DATA_DIR, class_names, find_pairs, load_registry, read_boxes, source_dir

PALETTE = ["#34c759", "#ff9500", "#a2845e", "#ffcc00", "#ff3b30", "#007aff", "#af52de", "#5ac8fa"]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*")
    ap.add_argument("-n", type=int, default=48, help="images per sheet")
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()

    for s in load_registry()["sources"]:
        if args.only and s["id"] not in args.only:
            continue
        root = source_dir(s)
        if not root.exists():
            continue
        pairs = find_pairs(root)
        if not pairs:
            continue
        names = class_names(s, root)
        random.Random(args.seed).shuffle(pairs)
        out = DATA_DIR / "sheets" / s["id"]
        out.mkdir(parents=True, exist_ok=True)
        cards = []
        for i, (img_path, lbl) in enumerate(pairs[: args.n]):
            with Image.open(img_path) as im:
                im = im.convert("RGB")
                im.thumbnail((480, 480))
                d = ImageDraw.Draw(im)
                W, H = im.size
                tags = []
                for cls, cx, cy, w, h in read_boxes(lbl):
                    name = names[cls] if cls < len(names) else str(cls)
                    color = PALETTE[cls % len(PALETTE)]
                    d.rectangle([(cx - w / 2) * W, (cy - h / 2) * H, (cx + w / 2) * W, (cy + h / 2) * H],
                                outline=color, width=3)
                    tags.append(name)
                thumb = f"{i:03d}.jpg"
                im.save(out / thumb, quality=80)
            caption = ", ".join(sorted(set(tags))) or "no boxes"
            cards.append(f'<figure><img src="{thumb}" loading="lazy"><figcaption>{html.escape(caption)}'
                         f'<br><small>{html.escape(img_path.name)}</small></figcaption></figure>')
        page = f"""<!doctype html><meta charset="utf-8"><title>{html.escape(s['id'])}</title>
<style>body{{font:14px -apple-system,system-ui,sans-serif;margin:24px;background:#f2f2f7}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}}
figure{{margin:0;background:#fff;border-radius:12px;overflow:hidden}}img{{width:100%;display:block}}
figcaption{{padding:8px}}small{{color:#8e8e93}}</style>
<h1>{html.escape(s['name'])}</h1>
<p>{len(pairs)} images · classes: {html.escape(str(names))} · license: {html.escape(str(s.get('license')))}</p>
<p><b>Check:</b> ground-level? storm debris (not marine/space/road litter)? boxes tight? license OK?
→ set <code>status: checked</code> in sources.yaml.</p>
<div class="grid">{''.join(cards)}</div>"""
        (out / "index.html").write_text(page)
        print(f"{s['id']}: {out / 'index.html'}")


if __name__ == "__main__":
    main()
