"""Draft boxes with Grounding DINO for a person to review. Never train on unreviewed output.

    pip install -r requirements-prelabel.txt          # GPU recommended; CPU works (~5–10 s/image)
    python scripts/prelabel.py data/raw/fema_pool/images data/prelabeled/fema_pool
    python scripts/prelabel.py ... --limit 20         # quick look first

Uses the Hugging Face port of Grounding DINO (IDEA-Research/grounding-dino-tiny, Apache-2.0).
Prompts come from `prompts:` in sources.yaml (prompt text → our class). Output is a YOLO
dataset with our class names (images/, labels/, data.yaml) plus prelabels.jsonl with scores.
Upload it to Roboflow as its own annotation batch, fix every box, export as YOLO into
data/raw/<new_id>/, and add a source entry for it (class_map: {} — names already match).
Expect thin objects (power lines) to need the most fixing. Resumable: images that already
have a label file are skipped.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from common import IMAGE_EXTS, load_registry

MODEL_ID = "IDEA-Research/grounding-dino-tiny"


def match_prompt(label: str, prompts: list[str]) -> str | None:
    """Grounding DINO returns the matched text span, which can run several prompts together
    ("damaged house house collapsed building"). Pick the prompt sharing the most words with
    the span's start, so the first phrase wins."""
    words = label.strip().lower().split()
    best, best_key = None, (0, 0)
    for p in prompts:
        pw = p.split()
        overlap = sum(w in words for w in pw)
        lead = sum(1 for a, b in zip(words, pw) if a == b)
        if (lead, overlap) > best_key and overlap >= max(1, len(pw) // 2):
            best, best_key = p, (lead, overlap)
    return best


def nms(dets: list[dict], iou_thr: float = 0.6) -> list[dict]:
    def iou(a, b):
        x0, y0 = max(a[0], b[0]), max(a[1], b[1])
        x1, y1 = min(a[2], b[2]), min(a[3], b[3])
        inter = max(0, x1 - x0) * max(0, y1 - y0)
        area = lambda r: (r[2] - r[0]) * (r[3] - r[1])
        return inter / (area(a) + area(b) - inter + 1e-9)
    kept = []
    for d in sorted(dets, key=lambda d: -d["score"]):
        if all(k["cls"] != d["cls"] or iou(k["box"], d["box"]) < iou_thr for k in kept):
            kept.append(d)
    return kept


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--box-threshold", type=float, default=0.25)  # 12 prompts in one query dilute scores
    ap.add_argument("--text-threshold", type=float, default=0.25)
    ap.add_argument("--limit", type=int)
    args = ap.parse_args()

    import torch
    from PIL import Image
    from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor

    reg = load_registry()
    classes, prompt_map = reg["classes"], {k.lower(): v for k, v in reg["prompts"].items()}
    prompts = list(prompt_map)
    text = ". ".join(prompts) + "."

    device = "cuda" if torch.cuda.is_available() else "cpu"
    torch.set_num_threads(os.cpu_count() or 4)
    processor = AutoProcessor.from_pretrained(MODEL_ID)
    model = AutoModelForZeroShotObjectDetection.from_pretrained(MODEL_ID).to(device).eval()

    (args.out / "images").mkdir(parents=True, exist_ok=True)
    (args.out / "labels").mkdir(parents=True, exist_ok=True)
    (args.out / "data.yaml").write_text(
        "path: .\ntrain: images\nval: images\nnames:\n" + "".join(f"  {i}: {c}\n" for i, c in enumerate(classes)))
    images = sorted(p for p in args.images.iterdir() if p.suffix.lower() in IMAGE_EXTS)
    images = images[: args.limit] if args.limit else images

    done = 0
    with open(args.out / "prelabels.jsonl", "a") as log:
        for img_path in images:
            lbl_path = args.out / "labels" / f"{img_path.stem}.txt"
            if lbl_path.exists():
                continue
            image = Image.open(img_path).convert("RGB")
            W, H = image.size
            inputs = processor(images=image, text=text, return_tensors="pt").to(device)
            with torch.no_grad():
                outputs = model(**inputs)
            res = processor.post_process_grounded_object_detection(
                outputs, inputs.input_ids, threshold=args.box_threshold,
                text_threshold=args.text_threshold, target_sizes=[(H, W)])[0]
            labels = res.get("text_labels", res.get("labels"))
            dets = []
            for box, score, label in zip(res["boxes"].tolist(), res["scores"].tolist(), labels):
                prompt = match_prompt(str(label), prompts)
                if prompt is None:
                    continue
                x0, y0, x1, y1 = (max(0.0, box[0]), max(0.0, box[1]), min(W, box[2]), min(H, box[3]))
                if x1 - x0 < 4 or y1 - y0 < 4:
                    continue
                dets.append({"cls": classes.index(prompt_map[prompt]), "prompt": prompt,
                             "score": round(score, 3), "box": [x0, y0, x1, y1]})
            dets = nms(dets)
            lbl_path.write_text("".join(
                f"{d['cls']} {(d['box'][0] + d['box'][2]) / 2 / W:.6f} {(d['box'][1] + d['box'][3]) / 2 / H:.6f} "
                f"{(d['box'][2] - d['box'][0]) / W:.6f} {(d['box'][3] - d['box'][1]) / H:.6f}\n" for d in dets))
            link = args.out / "images" / img_path.name
            if not link.exists():
                link.symlink_to(img_path.resolve())
            log.write(json.dumps({"image": img_path.name, "detections": dets}) + "\n")
            log.flush()
            done += 1
            if done % 25 == 0:
                print(f"  {done} images", flush=True)
    print(f"Draft labels for {done} new images in {args.out}. Review every box before training.")


if __name__ == "__main__":
    main()
