"""Train the detector on data/merged (run merge.py first). Use a GPU (Colab is fine).

    python scripts/train.py                       # yolo11n, 640px, 100 epochs
    python scripts/train.py --epochs 30 --name smoke-test
    python scripts/train.py --test                # also score the held-out test split

Augmentation leans toward storm-phone conditions: mosaic + mixup for clutter/occlusion,
strong brightness/saturation jitter for overcast light, slight rotation for tilted shots.
Ultralytics adds blur/median-blur automatically when `albumentations` is installed.
"""
from __future__ import annotations

import argparse

from common import DATA_DIR, TRAINING_DIR


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="yolo11n.pt")
    ap.add_argument("--data", default=str(DATA_DIR / "merged" / "data.yaml"))
    ap.add_argument("--epochs", type=int, default=100)
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--batch", type=int, default=-1, help="-1 = auto")
    ap.add_argument("--name", default="debris")
    ap.add_argument("--test", action="store_true")
    args = ap.parse_args()

    from ultralytics import YOLO

    model = YOLO(args.model)
    model.train(
        data=args.data, epochs=args.epochs, imgsz=args.imgsz, batch=args.batch,
        project=str(TRAINING_DIR / "runs"), name=args.name, exist_ok=False,
        mosaic=1.0, mixup=0.1, close_mosaic=10,
        hsv_h=0.015, hsv_s=0.6, hsv_v=0.5, degrees=5.0, fliplr=0.5,
        patience=30, plots=True,
    )
    if args.test:
        # Per-class mAP on photos from storms the model never saw. This is the number to trust.
        model.val(data=args.data, split="test", plots=True)


if __name__ == "__main__":
    main()
