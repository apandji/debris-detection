# Training status (local Mac, branch `model-local`)

_Updated 2026-10-03 by the local model-dev agent. v0 is still training; final metrics land when it finishes._

## Machine
Apple M4, 24 GB, MPS. Two venvs (both git-ignored):
- `training/.venv` (Python 3.14, torch 2.14): fetch, merge, prelabel, train.
- `training/.venv-export` (Python 3.12, `requirements-export.txt`): Core ML export only. coremltools has no native
  build for 3.14, and its torch frontend breaks on NumPy 2.

Long jobs (training, big downloads) run in a terminal tab under `caffeinate -i`, not as agent background jobs (2 h cap).
Keep the Mac on AC power with the lid open: one epoch took 148 min on battery with the lid closed.

## Data (task 1, done)
`fetch.py` rebuilt D-Fire and all checked Roboflow forks. `merge.py --link`, no prelabels:

| source | images | negatives | dupes removed | fallen_tree | damaged_building | rubble_debris | downed_line_or_pole | fire_smoke |
|---|---|---|---|---|---|---|---|---|
| dfire | 3000 | 1000 | 355 | 0 | 0 | 0 | 0 | 6806 |
| rf_fallen_trees_visual_deformity | 335 | 0 | 3 | 451 | 0 | 0 | 0 | 0 |
| rf_fallen_trees_palms | 1500 | 0 | 95 | 1953 | 0 | 0 | 0 | 0 |
| rf_fallen_trees_origin | 1793 | 0 | 899 | 2562 | 0 | 0 | 0 | 0 |
| rf_utility_pole | 1500 | 0 | 15 | 0 | 0 | 0 | 1816 | 0 |
| rf_house_damage_level | 379 | 0 | 0 | 0 | 498 | 0 | 0 | 0 |
| rf_hurricane_earthquake | 170 | 0 | 0 | 0 | 189 | 0 | 0 | 0 |

Splits: train 7457 images, val 853, test 0 (the held-out test set is not labeled yet).
`rf_fallen_trees_origin` loses half its images to phash dedup (overlap with the palms set or unnamed augmented copies).

Commons: `fema_pool` has all 4,602 photos; `fema_tornado_test` has all 193. Fixes made on the way:
- `commons.py --exclude-events-of` falls back to the committed `manifests/<id>_attribution.csv` and refuses an empty
  exclude set. Before, a fresh checkout would have pulled the test events into the pool. Pool checked: 0 test photos.
- Long titles sharing a 150-char prefix overwrote each other (70 photos, with attribution rows not matching the file).
  Now hash-suffixed; local `attribution.csv` repaired to one row per file.

## Labeling (task 2: drafts uploaded, human review pending)
Grounding DINO drafts (`prelabel.py`, MPS, ~2 s/image) attached in Roboflow with `scripts/upload_prelabels.py`.
Drafts use `add_to_dataset=False`, so nothing is in the Dataset or any version until a person approves it.

| Roboflow job | Images | What | Status |
|---|---|---|---|
| `prelabel-rubble-v0` | 2,407 | Pool photos with ≥1 rubble draft (all-class drafts) | Awaiting review; target ~300 for v1 |
| `heldout-test-drafts-v0` | 192 | Test photos, all-class drafts (1 photo had none) | Awaiting review; must stay split=test |

- 2,458 of 4,602 pool photos got a rubble draft; 47 not uploaded because their names match ambiguously in Roboflow.
- The cloud agent's 100-image batch `prelabel-rubble-v0` holds 4 drafts; the rest are blank.
- Drafts are noisy: downed_line_or_pole drafts appear on 94% of pool photos.
- Andrew's labeling to-do (links, steps, rules): https://claude.ai/code/artifact/f587e1f2-d692-4aff-869b-c9c5169820b9

## Baseline training (task 3, in progress)
- Smoke run `runs/smoke`: stopped at epoch 7/10 (2 h job cap); healthy, mAP50 0.23 → 0.55.
- **v0** `runs/v0`: YOLO11n, 100 epochs, 640, batch 16, MPS, ~7 min/epoch on AC power.
  Validation so far: epoch 30 mAP50 0.625; epoch 45 0.682; epoch 65 **0.693** (mAP50-95 0.371).
- Test-split number pending the test-set labels. Per-class results and downed-line recall come with the final eval.

## Export (task 4, pipeline verified on smoke weights)
`.venv-export/bin/python scripts/export.py runs/v0/weights/best.pt` → `runs/v0/weights/DebrisDetector.mlpackage`.
Checked on the smoke model: 640×640 input, NMS pipeline, class order matches the contract, 2.9 MB INT8.

**For the iOS agent:** Ultralytics pads the NMS stage to 80 class labels (`"5"`…`"79"` after our 5; MLProgram workaround,
ultralytics#22309). The padding columns always score 0 (verified by running the package), so take `labels.first`
and ignore any label that isn't one of the 5 classes. The package is not committed; the agent will hand over its path.

## Next
1. v0 finishes → final val metrics, export, hand `DebrisDetector.mlpackage` path to the orchestrator.
2. Andrew labels the test set → `model.val(split="test")` on v0, per-class + downed-line recall.
3. ~300 rubble photos approved → export from Roboflow as a new source, merge, train v1.
