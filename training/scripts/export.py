"""Export a trained model to Core ML for the iOS app.

    python scripts/export.py runs/v0/weights/best.pt --version v0   # → runs/v0/weights/DebrisDetector.mlpackage

Run on a Mac in the export env (`requirements-export.txt`, Python 3.12): Core ML INT8 quantization
only works on macOS, and coremltools has no native build for newer Pythons.
nms=True bakes non-max suppression in, so Vision returns VNRecognizedObjectObservation.
Then drag the .mlpackage into ios/DebrisMapper/ and swap MockDetector for a Vision request.

Contract with the iOS app (change only via the orchestrator): DebrisDetector.mlpackage, 640×640 input,
NMS baked in, class names in sources.yaml order. The script checks these and exits non-zero if one fails.

Note: Ultralytics pads the NMS stage to 80 classes (MLProgram shape workaround, ultralytics#22309).
The padding columns always score 0, so read the top label (`labels.first`) and ignore any name
that isn't one of our classes.
"""
from __future__ import annotations

import argparse
import platform
import shutil
import sys
from pathlib import Path

from common import load_registry

NAME = "DebrisDetector.mlpackage"


def stamp_version(pkg: Path, version: str) -> None:
    """Write the version into the package so the app can show it. iOS reads it as
    model.modelDescription.metadata[.versionString] (or creatorDefinedKey "debrismapper.version")."""
    import coremltools as ct

    m = ct.models.MLModel(str(pkg), skip_model_load=True)
    m.version = version
    m.short_description = f"Debris Mapper detector {version}"
    m.user_defined_metadata["debrismapper.version"] = version
    tmp = pkg.with_name(f"{pkg.stem}.tmp.mlpackage")  # saving onto its own path deletes it first
    m.save(str(tmp))
    shutil.rmtree(pkg)
    tmp.rename(pkg)


def check(pkg: Path, imgsz: int, classes: list[str]) -> list[str]:
    import coremltools as ct

    spec = ct.models.MLModel(str(pkg), skip_model_load=True).get_spec()
    problems = []
    image = spec.description.input[0].type.imageType
    if (image.width, image.height) != (imgsz, imgsz):
        problems.append(f"input is {image.width}x{image.height}, expected {imgsz}x{imgsz}")
    stages = [m for m in spec.pipeline.models] if spec.WhichOneof("Type") == "pipeline" else []
    nms = [m for m in stages if m.WhichOneof("Type") == "nonMaximumSuppression"]
    if not nms:
        problems.append("no NMS stage in the pipeline")
    else:
        labels = list(nms[0].nonMaximumSuppression.stringClassLabels.vector)
        if labels[: len(classes)] != classes:
            problems.append(f"class labels {labels[:len(classes)]} != {classes}")
        print(f"  NMS labels: {labels[:len(classes)]} (+{len(labels) - len(classes)} zero-score padding)")
    size_mb = sum(f.stat().st_size for f in pkg.rglob("*") if f.is_file()) / 1e6
    print(f"  input {image.width}x{image.height}, size {size_mb:.1f} MB")
    if size_mb > 4:
        problems.append(f"{size_mb:.1f} MB is over the ~3 MB target")
    print(f"  version: {spec.description.metadata.versionString}")
    return problems


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("weights")
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--version", required=True, help="model version from manifests/models.yaml, e.g. v0")
    args = ap.parse_args()

    if platform.system() != "Darwin":
        print("Warning: not macOS — INT8 quantization will be skipped by Core ML tools.")
    from ultralytics import YOLO

    path = Path(YOLO(args.weights).export(format="coreml", int8=True, nms=True, imgsz=args.imgsz))
    out = path.with_name(NAME)
    if out.exists():
        shutil.rmtree(out)
    path.rename(out)
    stamp_version(out, args.version)
    print(f"Core ML package: {out} ({args.version})")
    problems = check(out, args.imgsz, load_registry()["classes"])
    for p in problems:
        print(f"  CONTRACT: {p}")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
