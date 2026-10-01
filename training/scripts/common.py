"""Shared helpers: paths, the source registry, and YOLO dataset discovery."""
from __future__ import annotations

import re
from pathlib import Path

import yaml

TRAINING_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = TRAINING_DIR / "data"
RAW_DIR = DATA_DIR / "raw"
SOURCES_FILE = TRAINING_DIR / "sources.yaml"
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def load_registry() -> dict:
    with open(SOURCES_FILE) as f:
        return yaml.safe_load(f)


def source_dir(source: dict) -> Path:
    return RAW_DIR / source["id"]


def set_status(source_id: str, status: str) -> None:
    """Edit one source's `status:` line in place, keeping the file's comments."""
    text = SOURCES_FILE.read_text()
    block = re.compile(rf"(- id: {re.escape(source_id)}\n(?:(?!  - id: ).*\n)*?\s+status: )\S+")
    new, n = block.subn(rf"\g<1>{status}", text, count=1)
    if n:
        SOURCES_FILE.write_text(new)


def class_names(source: dict, root: Path) -> list[str]:
    """Class names for a source: `names:` in the registry, else the dataset's own data.yaml."""
    if source.get("names"):
        return list(source["names"])
    for yml in sorted(root.rglob("data.yaml")):
        with open(yml) as f:
            names = (yaml.safe_load(f) or {}).get("names")
        if isinstance(names, dict):
            return [names[k] for k in sorted(names, key=int)]
        if isinstance(names, list):
            return names
    return []


def label_path_for(image: Path) -> Path:
    """YOLO convention: .../images/x.jpg → .../labels/x.txt (else a .txt beside the image)."""
    parts = list(image.parts)
    for i in range(len(parts) - 1, -1, -1):
        if parts[i] == "images":
            parts[i] = "labels"
            return Path(*parts).with_suffix(".txt")
    return image.with_suffix(".txt")


def find_pairs(root: Path) -> list[tuple[Path, Path | None]]:
    """Every image under root with its label file (None if missing)."""
    pairs = []
    for img in sorted(root.rglob("*")):
        if img.suffix.lower() in IMAGE_EXTS and img.is_file():
            lbl = label_path_for(img)
            pairs.append((img, lbl if lbl.exists() else None))
    return pairs


def read_boxes(label: Path | None) -> list[tuple[int, float, float, float, float]]:
    """YOLO boxes (cls, cx, cy, w, h). Polygon rows (segmentation exports) become their bbox."""
    if label is None:
        return []
    boxes = []
    for line in label.read_text().splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        cls, nums = int(float(parts[0])), [float(p) for p in parts[1:]]
        if len(nums) == 4:
            boxes.append((cls, *nums))
        elif len(nums) >= 6 and len(nums) % 2 == 0:
            xs, ys = nums[0::2], nums[1::2]
            x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
            boxes.append((cls, (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0))
    return boxes
