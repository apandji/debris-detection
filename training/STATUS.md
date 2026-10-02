# Training status (local Mac, branch `model-local`)

_Updated 2026-10-02 by the local model-dev agent. Work in progress; see "Resume" below._

## Machine
Apple M4, 24 GB, MPS works (torch 2.14.1, Python 3.14 venv at `training/.venv`).
Disk is ~98% full (~11 GB free) and shrinking from things outside this repo; `data/merged` uses symlinks.
coremltools has no native build for Python 3.14, so export needs a separate Python 3.12 env (not set up yet).

## Data (task 1, done)
`fetch.py` rebuilt D-Fire and all checked Roboflow forks. `merge.py` (no prelabels, `--link`):

| source | images | negatives | dupes removed | fallen_tree | damaged_building | rubble_debris | downed_line_or_pole | fire_smoke |
|---|---|---|---|---|---|---|---|---|
| dfire | 3000 | 1000 | 355 | 0 | 0 | 0 | 0 | 6806 |
| rf_fallen_trees_visual_deformity | 335 | 0 | 3 | 451 | 0 | 0 | 0 | 0 |
| rf_fallen_trees_palms | 1500 | 0 | 95 | 1953 | 0 | 0 | 0 | 0 |
| rf_fallen_trees_origin | 1793 | 0 | 899 | 2562 | 0 | 0 | 0 | 0 |
| rf_utility_pole | 1500 | 0 | 15 | 0 | 0 | 0 | 1816 | 0 |
| rf_house_damage_level | 379 | 0 | 0 | 0 | 498 | 0 | 0 | 0 |
| rf_hurricane_earthquake | 170 | 0 | 0 | 0 | 189 | 0 | 0 | 0 |

Splits: train 7457 images, val 853, test 0 (held-out test set is not labeled yet).
`rf_fallen_trees_origin` loses half its images to phash dedup (overlap with the palms set or unnamed augmented copies).

Commons pool: downloading `fema_pool` (4,602 candidates) with `--exclude-events-of fema_tornado_test`.
`commons.py` now reads the committed `manifests/fema_tornado_test_attribution.csv` when `data/raw/fema_tornado_test/` is absent,
and refuses to run with an empty exclude set (before, a fresh checkout would have pulled test events into the pool).

## Rubble prelabels (task 2, in progress)
- Cloud agent left batch `prelabel-rubble-v0` with 100 images (all tagged), but only 4 have drafts.
- `prelabel.py` now runs on MPS (~6 s/image). Output: `data/prelabeled/fema_pool/`.
- Drafts are attached with `scripts/upload_prelabels.py` to the existing pool images (no re-upload), using
  `add_to_dataset=False` and `overwrite=False`. Roboflow files them in annotation job `prelabel-rubble-v0`, out of the Dataset.
  Only images with ≥1 rubble draft are sent (all their draft boxes go along). About half the photos get a rubble draft.
- Drafts are noisy (12 prompts in one query; scores 0.25–0.5, 3–8 boxes/image). Unreviewed drafts never go into training.
- 1 image uploaded so far (test). Pool image names in Roboflow differ from local names; matching is by normalized name, one-to-one only.

## Baseline training (task 3, in progress)
Smoke run `runs/smoke` (10 epochs, MPS, batch 16) runs at ~30 min/epoch while sharing the GPU with Grounding DINO.
A 100-epoch v0 on this Mac would take roughly a day or more; consider Colab (`notebooks/train_colab.ipynb`).

## Resume
```bash
cd training && source .venv/bin/activate && set -a && source ~/Developer/debris-detection/training/.env && set +a
python scripts/commons.py download manifests/tornado.jsonl fema_pool --exclude-events-of fema_tornado_test   # resumes
python scripts/prelabel.py data/raw/fema_pool/images data/prelabeled/fema_pool                               # resumes
python scripts/upload_prelabels.py data/prelabeled/fema_pool                                                 # resumes
python scripts/train.py --epochs 10 --name smoke --device mps --batch 16
```
