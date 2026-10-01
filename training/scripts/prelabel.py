"""Draft boxes with Grounding DINO for a person to review. Never train on unreviewed output.

    pip install -r requirements-prelabel.txt          # GPU strongly recommended (Colab)
    python scripts/prelabel.py data/raw/fema_pool/images data/prelabeled/fema_pool

Prompts come from `prompts:` in sources.yaml (prompt text → our class). Output is a YOLO
dataset with our class names. Upload it to Roboflow or CVAT, fix every box, export as YOLO
into data/raw/<new_id>/, and add a source entry for it (class_map: {} — names already match).
Expect thin objects (power lines) to need the most fixing.
"""
from __future__ import annotations

import argparse
from pathlib import Path

from common import load_registry


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("images", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--ext", default=".jpg")
    ap.add_argument("--box-threshold", type=float, default=0.35)
    ap.add_argument("--text-threshold", type=float, default=0.25)
    args = ap.parse_args()

    from autodistill.detection import CaptionOntology
    from autodistill_grounding_dino import GroundingDINO

    prompts = load_registry()["prompts"]
    model = GroundingDINO(
        ontology=CaptionOntology(prompts),
        box_threshold=args.box_threshold,
        text_threshold=args.text_threshold,
    )
    model.label(input_folder=str(args.images), extension=args.ext, output_folder=str(args.out))
    print(f"Draft labels in {args.out}. Review every box before training.")


if __name__ == "__main__":
    main()
