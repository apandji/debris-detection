# Training the Debris Mapper detector

Fine-tunes YOLO11n on ground-level storm photos and exports it to Core ML for the iOS app.
Background and dataset research: `../research/yolo-datasets.md`.

**Classes (v0):** `fallen_tree`, `damaged_building`, `rubble_debris`, `downed_line_or_pole`, `fire_smoke`.
These go beyond the app's 4 current classes; the app gets updated when the first model lands.

**License:** Ultralytics is AGPL-3.0, so the app (open source, not on the App Store) must ship under an AGPL-compatible license.

## Workflow

| Step | Command | Where |
|---|---|---|
| 0. Setup | `pip install -r requirements.txt` | Colab (GPU) or Mac |
| 1. Download | `ROBOFLOW_API_KEY=… python scripts/fetch.py` · storm photos: `python scripts/commons.py crawl/events/download` · manual: `fetch.py --list` | anywhere |
| 2. Eyeball | `python scripts/sheet.py` → open `data/sheets/<id>/index.html`, then set `status: checked` | anywhere |
| 3. Merge | `python scripts/merge.py --check`, fill `class_map`, then `python scripts/merge.py` | anywhere |
| 4. Train | `python scripts/train.py --test` | GPU (`notebooks/train_colab.ipynb`) |
| 5. Export | `python scripts/export.py runs/debris/weights/best.pt` | **Mac** (INT8 needs macOS) |
| Gaps | `python scripts/prelabel.py <images> <out>` → review every box in Roboflow/CVAT → add as a new source | GPU |

`sources.yaml` is the single registry and checklist: every dataset, its license, viewpoint,
class mapping, cap, and status. Nothing trains unless a person marked it `checked`.
`data/` and `runs/` are git-ignored.

## Rules

- **Test set is sacred.** `role: test` photos (hand-labeled FEMA tornado photos from storms not used in training) are never trained on. `merge.py` removes training duplicates of test photos.
- **Prelabels are drafts.** Grounding DINO output is reviewed box by box before it becomes a source.
- **Licenses travel with data.** Don't add a source without its license; prefer CC0 / CC BY / public domain. NC or unclear sources stay out of the default training set.
- **Track missed downed lines** separately (recall at low confidence). It's the safety metric.
