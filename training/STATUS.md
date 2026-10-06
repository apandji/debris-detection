# Training status (local Mac, branch `model-local`)

_Updated 2026-10-03 by the local model-dev agent. v0 trained and exported; test-set score waits on labels._

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

## Baseline training (task 3, done; test number pending)
- Smoke run `runs/smoke`: stopped at epoch 7/10 (2 h job cap); healthy, mAP50 0.23 → 0.55.
- **v0** `runs/v0`: YOLO11n, 100 epochs, 640, batch 16, MPS. Finished 2026-10-03 in 16.1 h (one epoch lost to sleep on battery).

v0 `best.pt` on the **validation** split (852 images, 1,237 boxes; same sources as train, so optimistic):

| class | P | R | mAP50 | mAP50-95 | recall @conf 0.10 | @0.25 |
|---|---|---|---|---|---|---|
| fallen_tree | 0.660 | 0.548 | 0.608 | 0.299 | 0.724 | 0.597 |
| damaged_building | 0.745 | 0.767 | 0.777 | 0.509 | 0.808 | 0.767 |
| rubble_debris | — | — | — | — | — | — |
| downed_line_or_pole | 0.737 | 0.719 | 0.762 | 0.447 | **0.832** | 0.765 |
| fire_smoke | 0.690 | 0.650 | 0.690 | 0.363 | 0.757 | 0.676 |
| **all** | 0.708 | 0.671 | **0.709** | **0.404** | | |

P/R are at the max-F1 confidence. Recall columns are at IoU 0.5. rubble_debris has no training or val boxes, so v0 never predicts it.
- **Test split: pending** the held-out labels (`heldout-test-drafts-v0`). Then: `model.val(split="test")`.
- Weakest: fallen_tree recall (0.55). The tree sets are web-scraped with loose boxes; worth checking on the test set before acting.
- 1 D-Fire val label has out-of-bounds coordinates and is ignored by Ultralytics (`dfire__WEB11598`).

## Export (task 4, done)
`.venv-export/bin/python scripts/export.py runs/v0/weights/best.pt` → **`training/runs/v0/weights/DebrisDetector.mlpackage`**
(git-ignored; on Andrew's Mac in this worktree: `~/Developer/debris-detection/.claude/worktrees/fervent-golick-a0afaa/training/runs/v0/weights/`).
Contract checks pass: 640×640 input, NMS pipeline, class order matches, 2.7 MB INT8.
INT8 vs PyTorch on 40 val photos: same set of classes found on 39/40.

**For the iOS agent:** Ultralytics pads the NMS stage to 80 class labels (`"5"`…`"79"` after our 5; MLProgram workaround,
ultralytics#22309). The padding columns always score 0 (verified by running the package), so take `labels.first`
and ignore any label that isn't one of the 5 classes. The package is not committed; the agent will hand over its path.

## Next
1. Orchestrator / iOS agent: bundle `DebrisDetector.mlpackage` (path above). It cannot detect rubble yet.
2. Andrew labels the test set → `model.val(split="test")` on v0, per-class + downed-line recall.
3. ~300 rubble photos approved → export from Roboflow as a new source, merge, train v1 (~16 h here).

## Reference (from the cloud model-dev handoff, 2026-10-02)

### Every source

"Lives in" says where the images are. Git never holds images; `data/` is rebuilt with `fetch.py` / `commons.py`.

| Source id | Origin | License | Lives in | Labels | Status | Usable images → boxes |
|---|---|---|---|---|---|---|
| dfire | [github.com/gaiasd/DFireDataset](https://github.com/gaiasd/DFireDataset) (Kaggle mirror) | CC0 1.0 | Kaggle download → `data/raw/dfire` | labeled (fire, smoke) | checked | 11,689 → 26,557 (capped to 3,000) |
| rf_fallen_trees_visual_deformity | [visual-deformity/fallen-trees-pka1c](https://universe.roboflow.com/visual-deformity/fallen-trees-pka1c) | CC BY 4.0 | fork `pandji/fallen-trees-pka1c-w3k7t` v1 | labeled | checked | 335 → 451 |
| rf_fallen_trees_origin | [testws-u4esm/fallen_trees_origin-0tn0t](https://universe.roboflow.com/testws-u4esm/fallen_trees_origin-0tn0t) | CC BY 4.0 (on fork) | fork `pandji/fallen_trees_origin-0tn0t-hcpdf` v1 | labeled | checked | 1,793 → 2,562 |
| rf_fallen_trees_palms | [overflow-thaap/fallen-trees-with-palms](https://universe.roboflow.com/overflow-thaap/fallen-trees-with-palms) | CC BY 4.0 | fork `pandji/fallen-trees-with-palms-70rke` v1 | labeled | checked | 2,723 unique → 3,579 (capped to 1,500) |
| rf_utility_pole | [dequillaprojects/utility-pole-y8w7k](https://universe.roboflow.com/dequillaprojects/utility-pole-y8w7k) | CC BY 4.0 | fork `pandji/utility-pole-y8w7k-zfcgm` v1 | labeled (Compromised-Pole) | checked | 1,541 unique → 1,870 |
| rf_house_damage_level | [anne-pearl-inting/house-damage-level](https://universe.roboflow.com/anne-pearl-inting/house-damage-level) | CC BY 4.0 | fork `pandji/house-damage-level-ughkd` v1 | labeled | checked, filtered | 767 → 379 after excluding 388 (`manifests/excludes/`) → 498 |
| rf_hurricane_earthquake | [first-round-testing-datasets-zrdeg/hurricane---earthquake](https://universe.roboflow.com/first-round-testing-datasets-zrdeg/hurricane---earthquake) | CC BY 4.0 | fork `pandji/hurricane---earthquake-rdui8` v1 | labeled (destroyed/major kept) | checked | 170 → 189 |
| rf_damaged_building_tls | [tls-fx17y/damaged-building-jytkn](https://universe.roboflow.com/tls-fx17y/damaged-building-jytkn) | CC BY 4.0 | fork `pandji/damaged-building-jytkn-hohdk` v1 (unused) | labeled | **rejected** (Andrew): earthquake/war high-rises, watermark shortcut | — |
| rf_fallen_trees_steve_chun | [rogue-recon/fallen-trees](https://universe.roboflow.com/rogue-recon/fallen-trees) | Public Domain | not forked | labeled | rejected: drone top-down | — |
| rf_rubble_detection | [rubble-project/rubble-detection](https://universe.roboflow.com/rubble-project/rubble-detection) | unknown | not forked | labeled | rejected: satellite | — |
| rf_damaged_building | [building-damaged/damaged-building](https://universe.roboflow.com/building-damaged/damaged-building) | CC BY 4.0 | not forked | labeled | rejected: satellite, 43 imgs | — |
| rf_disaster_detection | [asderids/disaster_detection-d9uqt](https://universe.roboflow.com/asderids/disaster_detection-d9uqt) | unknown | not forked | — | rejected: project is empty | — |
| fema_tornado_test | Commons: "Images from FEMA, 2007 Central Florida tornadoes" + "…2000 Southwest Georgia tornado outbreak" | Public domain (all 193) | `pandji/storm-debris-detection`, split **test**, tag `heldout-test`; list in `manifests/fema_tornado_test_attribution.csv` | **needs human labels** | downloaded | 193 images |
| fema_pool | Commons tornado-damage categories (141 events, minus the 2 test events) | per photo: PD 73%, CC BY-SA, CC BY, CC0 (no NC/ND) | `pandji/storm-debris-detection`, split train, tags `commons`, `pool`, event; list in `manifests/fema_pool_attribution.csv` | **needs human labels** (Grounding DINO drafts for some) | downloaded, uploaded unlabeled | 4,602 images |
| gdbda | [Liu et al. 2022](https://www.mdpi.com/2072-4292/14/12/2763) | unknown | — | labeled | todo (request from authors) | — |
| incidents1m | [IncidentsDataset](https://github.com/ethanweber/IncidentsDataset) | labels MIT; images © owners | — | classification only | todo | — |

### Decisions recorded (Andrew, 2026-10-02)

- **Forks:** keep the 7 private forks in `pandji` until the project wraps (~1 week), then clean up. They use included storage credits only.
- **Licensing:** Universe sets are accepted for this open-source research model, on three conditions: never republish the images (git holds manifests only); credit every dataset (license + URL above and in `sources.yaml`); keep the held-out test set public-domain only (it is: all 193 are PD FEMA photos).
- **rf_utility_pole** includes Google Street View frames and scraped photos. Replace it with our own labels (app-confirmed boxes, reviewed Commons drafts) over time.
- **rf_house_damage_level:** included minus AI-generated-looking and aerial frames, filtered by eye on contact sheets; the list is reproducible (`manifests/excludes/rf_house_damage_level.txt`, honored by `merge.py`). 767 → 379.
- **rf_damaged_building_tls:** excluded.
- **Rubble:** keep `rubble_debris` as its own class and source it ourselves (prelabel drafts → human review).

### Gaps

1. **rubble_debris: no data.** Every public rubble set we found is satellite or aerial. Plan below.
2. **damaged_building: thin (549 images)**, and two-thirds of it comes from a set we had to filter heavily.
   Wind damage to wood-frame houses is what the app needs; the Commons pool is full of it once labeled.
3. **downed_line_or_pole: one source.** 1,541 images, all from rf_utility_pole: snapped/leaning poles,
   storms and vehicle crashes, ground level. Boxes cover the **pole, not the wire**; nothing labels
   downed wires on their own. Some boxes are streetlights or signs. Expect weak recall on wires-only
   scenes, which is the safety case, so track low-confidence recall on the test set.
4. **Domain shift.** Most Universe images are scraped news/stock photos (watermarks, Chinese/Philippine
   typhoons). The HDR filter on rf_hurricane_earthquake and pre-augmentation on palms/poles are odd.
   The test set is US tornado photos, so it will show how much this matters.
