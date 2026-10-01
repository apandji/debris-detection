"""Export a trained model to Core ML for the iOS app.

    python scripts/export.py runs/debris/weights/best.pt

Run on a Mac: Core ML INT8 quantization only works on macOS (elsewhere you get FP16/FP32).
nms=True bakes non-max suppression in, so Vision returns VNRecognizedObjectObservation.
Then drag the .mlpackage into ios/DebrisMapper/ and swap MockDetector for a Vision request.
"""
from __future__ import annotations

import argparse
import platform


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("weights")
    ap.add_argument("--imgsz", type=int, default=640)
    args = ap.parse_args()

    if platform.system() != "Darwin":
        print("Warning: not macOS — INT8 quantization will be skipped by Core ML tools.")
    from ultralytics import YOLO

    path = YOLO(args.weights).export(format="coreml", int8=True, nms=True, imgsz=args.imgsz)
    print(f"Core ML package: {path}")


if __name__ == "__main__":
    main()
