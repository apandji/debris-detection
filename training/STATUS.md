# Training data status

_Model dev agent, 2026-10-02. Branch `model-dev`. Registry: `sources.yaml`. Pipeline: `README.md`._

**Bottom line:** we can train a first baseline for 4 of the 5 classes today. `rubble_debris` has no
labeled data; drafts for it are being made from our own Commons photos and need human review.
`damaged_building` is thin (549 images). Nothing here has been trained yet; there is no GPU in the
cloud container, so training and prelabeling move to the local Mac agent (`model-local`).

## Per-class counts (what `merge.py` would use today)

Checked sources only, after dropping augmented copies, the house-damage exclude list, and caps.

| Class | Images | Boxes | Sources |
|---|---:|---:|---|
| `fallen_tree` | 3,628 | 4,966 | rf_fallen_trees_origin 1,793 · rf_fallen_trees_palms 1,500 (cap) · rf_fallen_trees_visual_deformity 335 |
| `damaged_building` | 549 | 687 | rf_house_damage_level 379 · rf_hurricane_earthquake 170 |
| `rubble_debris` | **0** | **0** | none — see Gaps |
| `downed_line_or_pole` | 1,541 | 1,870 | rf_utility_pole 1,541 (every unique original) |
| `fire_smoke` | 3,000 (+1,000 negatives) | 6,806 | dfire (cap) |

Held-out test set: **193** photos, unlabeled (see below). No class counts until it's labeled.

## Every source

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

## Decisions recorded (Andrew, 2026-10-02)

- **Forks:** keep the 7 private forks in `pandji` until the project wraps (~1 week), then clean up. They use included storage credits only.
- **Licensing:** Universe sets are accepted for this open-source research model, on three conditions: never republish the images (git holds manifests only); credit every dataset (license + URL above and in `sources.yaml`); keep the held-out test set public-domain only (it is: all 193 are PD FEMA photos).
- **rf_utility_pole** includes Google Street View frames and scraped photos. Replace it with our own labels (app-confirmed boxes, reviewed Commons drafts) over time.
- **rf_house_damage_level:** included minus AI-generated-looking and aerial frames, filtered by eye on contact sheets; the list is reproducible (`manifests/excludes/rf_house_damage_level.txt`, honored by `merge.py`). 767 → 379.
- **rf_damaged_building_tls:** excluded.
- **Rubble:** keep `rubble_debris` as its own class and source it ourselves (prelabel drafts → human review).

## Held-out test set

193 public-domain FEMA photos from two events that no training source uses (152 from the 2007
Central Florida tornadoes, 41 from the 2000 Southwest Georgia outbreak). Uploaded unlabeled to
`pandji/storm-debris-detection`, split test, tags `heldout-test` + `commons` + event name, in batches
"heldout-test FEMA …". Andrew and the orchestrator label these by hand. `fema_pool` downloads skip both
events (`--exclude-events-of fema_tornado_test`), and `merge.py` dedups training copies against test.

## Gaps

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

## Pool and prelabels (rubble plan)

- **Pool:** 4,602 Commons photos from 139 events (test events excluded). List and per-photo
  licenses are in `manifests/fema_pool_attribution.csv`. All uploaded **unlabeled** to
  `pandji/storm-debris-detection` as split train, tags `commons` + `pool`: 4,502 in batch
  `commons-pool`, 100 in batch `prelabel-rubble-v0` (also tagged `prelabel-rubble-v0`).
  **Per-event tags are not added yet** (tags must be `[A-Za-z0-9_-]`; plan: `event-<slug>`
  via `images_batch_update_metadata`, ≤1000 per call). Some photos aren't damage (officials at
  press events, aerials); reviewers skip them.
- **Grounding DINO drafts** (`scripts/prelabel.py`, IDEA-Research/grounding-dino-tiny,
  threshold 0.30, all 5 classes): **stopped at 1,568 of 4,602** on CPU (Andrew moved GPU work
  to a local Mac agent). The drafts done so far are committed as labels-only JSON:
  `manifests/prelabels/fema_pool_gdino_drafts.jsonl` (one line per image: file name, and for
  each box the class, prompt, score, and xyxy pixel box). Of those, ~22% have a
  `rubble_debris` draft. Drafts are noisy (spurious pole/smoke boxes, standing trees as fallen);
  expect to delete about half of the boxes.
- **`prelabel-rubble-v0`:** 100 images with the strongest rubble drafts, spread across 42 events
  (`manifests/prelabels/prelabel-rubble-v0.txt`). Images are uploaded; drafts go on as
  *predictions* (`annotations_save`, `prediction_routing: unassigned`, never `add_to_dataset`).
  **Only 4 of 100 have drafts attached**; one MCP call per image was too many permission prompts.
  The other 96 still need theirs (or a bulk upload with `ROBOFLOW_API_KEY`).
- Nothing from the pool trains until a person has reviewed it and it's exported as a new source.

## Proposed next step

**Run a first baseline now, in parallel with labeling.** Train YOLO11n on the local Mac (MPS) on what's checked
(4 classes, ~8.7k images) and score it on the held-out test set once Andrew labels it. That tells us
early how badly the scraped/Universe domain transfers to US tornado photos. Meanwhile, review
`prelabel-rubble-v0` in Roboflow, then the next batches (rubble first, then damaged_building
and downed lines). Retrain once ~500 reviewed rubble images exist. Prelabeling and training now belong to the local Mac agent (MPS), branch `model-local`.

## Handoff for the local agent (`model-local`, cut from `model-dev`)

**Done:** registry vetted (`sources.yaml`); 7 private forks in `pandji` with raw v1 versions; test set
(193) and pool (4,602) uploaded to `pandji/storm-debris-detection`; manifests committed; `merge.py`
dedups Roboflow augmented copies and honors `manifests/excludes/`.

**Half-done:** (1) Grounding DINO drafts: 1,568 / 4,602 pool images; (2) `prelabel-rubble-v0`:
images uploaded, drafts attached to 4 / 100; (3) per-event tags on the pool not applied.

**Next commands** (from `training/`, with `ROBOFLOW_API_KEY` set in `.env` / the shell):

```bash
pip install -r requirements.txt -r requirements-prelabel.txt
python scripts/fetch.py                       # D-Fire + the 7 checked/forked Roboflow sources
python scripts/commons.py download manifests/tornado.jsonl fema_pool --exclude-events-of fema_tornado_test
python scripts/commons.py download manifests/tornado.jsonl fema_tornado_test \
  --events "Images from FEMA, 2007 Central Florida tornadoes" "Images from FEMA, 2000 Southwest Georgia tornado outbreak"
python scripts/prelabel.py data/raw/fema_pool/images data/prelabeled/fema_pool   # MPS; resumable
python scripts/merge.py --check && python scripts/merge.py
python scripts/train.py --epochs 100          # baseline, 4 classes (no rubble yet); --test once test labels exist
```

Then attach drafts for the remaining 96 `prelabel-rubble-v0` images (list in
`manifests/prelabels/prelabel-rubble-v0.txt`) as predictions, never adding them to the dataset.
With an API key the Roboflow SDK can upload image + YOLO label together for the next batches.
Core ML contract is unchanged: `DebrisDetector.mlpackage`, 640 input, NMS, class order as in `sources.yaml`.

## Housekeeping notes

- Universe export links from the Roboflow API 404 (stale zips), and there's no `ROBOFLOW_API_KEY` in
  the cloud container. Every Universe set was forked **private** into `pandji`, given a raw version
  (auto-orient only), and exported. `sources.yaml` points `fetch.py` at the forks.
- Commons throttles original files hard (429, Retry-After 600). `commons.py` now requests Wikimedia's
  standard thumbnail sizes, backs off, and a re-run picks up anything skipped.
- `merge.py` keeps one image per Roboflow original (`<stem>.rf.<hash>`): rf_utility_pole ships ~5
  augmented copies per photo and palms ~3, which would otherwise leak across train/val.
- `prelabel.py` uses the Hugging Face Grounding DINO port (GitHub release downloads are blocked in the
  container); CPU is ~5–6 s/image.
