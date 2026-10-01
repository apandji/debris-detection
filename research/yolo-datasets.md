# Public datasets for a ground-level storm-debris YOLO detector

*Research note, 2026-10-01. Written for the design/PM critique. Scope: datasets you could use to fine-tune a YOLOv8n/YOLO11n detector that runs on-device via Core ML (INT8) on **phone-height, ground-level** photos. Aerial, drone and satellite data are mostly out of scope.*

**How sure each fact is.** Each number and license carries one of these tags:
- **[V]** I read it on the dataset's own page or repo.
- **[S]** It comes from search-engine snippets of the paper or listing; I could not open the page.
- **[U]** Unverified or unknown.

The research proxy blocked roboflow.com, arxiv.org, huggingface.co, crisisnlp.qcri.org and mdpi.com, so many entries are **[S]**. Re-check every license before anyone downloads data.

---

## TL;DR

1. **No public dataset has ground-level bounding boxes for storm debris.** The large ground-level disaster sets (Incidents1M, MEDIC, CrisisMMD) only say what the whole photo shows. They have no boxes. The sets that do have boxes are mostly aerial or drone (RescueNet, FloodNet, TTPLA, C2A, xBD). The exceptions are small Roboflow Universe projects and D-Fire.
2. **Fire and smoke is the only class that is solved off the shelf.** D-Fire has about 21.5k ground and surveillance images with about 26.5k YOLO boxes. Its compilation is released CC0 [S]. Fallen trees and rubble have a scattered set of small Roboflow projects (hundreds to a few thousand images each), mostly CC BY 4.0 [S]. **Downed power lines have essentially no ground-level boxes.** You would need to label them yourself.
3. **Taxonomy A (the current 4 classes) is more trainable than taxonomy B.** Every A class has *some* box data. B's `hazardous_leak` covers gas, propane, fire and smoke, but only fire and smoke has data. B's `bystander_survivor` and `road_impassable` have no ground-level boxes and are hard to define as a box at all. A **hybrid** fits better: A's 4 classes, plus `fire_smoke`, with `wire_pole_hazard` folded in as the broader name for power lines.
4. **Starter recipe:** combine D-Fire, the best 3–5 Roboflow fallen-tree, rubble and damage projects, and GDBDA if it can be obtained. Add a box pass over ground-level photos pulled from Incidents1M and MEDIC, using Grounding DINO or OWLv2 to suggest boxes and a human to check every one. Use **real tornado photos from FEMA, which are public domain, as the held-out validation set**. Expect roughly 3–8k usable images at first, before the app's own confirmed labels start adding more.
5. **Licensing red flags:**
   - **Ultralytics YOLOv8 and YOLO11 are AGPL-3.0.** A closed-source App Store app needs an Ultralytics Enterprise License, or a switch to a permissively licensed detector. This matters more than any dataset license.
   - xBD is CC BY-NC-SA, so non-commercial only.
   - CrisisMMD and MEDIC come from Twitter/X and carry NC-SA terms on at least one distribution.
   - CrowdHuman uses a custom Megvii license.
   - Incidents1M is MIT-licensed, but it is a list of web URLs, and the copyright of each image stays with its owner.

---

## 1. Dataset comparison

Viewpoint key: **G** = ground or street level, **S** = surveillance or CCTV, **UAV** = drone, **Air** = crewed aircraft, **Sat** = satellite.

| Dataset | Link | Size | Annotation | Classes (relevant) | View | Disasters | License / commercial? | Fit A / B |
|---|---|---|---|---|---|---|---|---|
| **D-Fire** | [github.com/gaiasd/DFireDataset](https://github.com/gaiasd/DFireDataset) | 21,527 imgs; 14,692 fire + 11,865 smoke boxes [V] | **bbox (YOLO format)** [V] | fire, smoke | G / S | wildfire, urban fire | Compilation CC0 1.0, images described as public domain [S]. **Commercial OK** (re-check the LICENSE file) | A: none (no class). B: **strong for `hazardous_leak` (fire, smoke only)** |
| **Roboflow – Fallen Trees (visual-deformity)** | [link](https://universe.roboflow.com/visual-deformity/fallen-trees-pka1c) | [U] | bbox [S] | fallen tree | [U] | storm | CC BY 4.0 [S]. Commercial OK with attribution | A: fallen tree. B: `road_impassable` (partial) |
| **Roboflow – Fallen Trees (steve-chun)** | [link](https://universe.roboflow.com/steve-chun/fallen-trees-1dfmg) | [U] | bbox [S] | roots, treefall [S] | [U] | storm | Public Domain [S] | A: fallen tree |
| **Roboflow – Fallen trees (with palms)** | [link](https://universe.roboflow.com/overflow-thaap/fallen-trees-with-palms) | [U] | bbox [S] | fallen tree, palms | [U] (likely hurricane) | hurricane | CC BY 4.0 [S] | A: fallen tree |
| **Roboflow – Fallen_Trees_all_trunk** | [link](https://universe.roboflow.com/object-detection-oudof/fallen_trees_all_trunk) | [U] | bbox [S] | trunk | [U] (may be forest or aerial windthrow) | — | CC BY 4.0 [S] | A: fallen tree (check viewpoint) |
| **Roboflow – Fallen_Trees_Origin** | [link](https://universe.roboflow.com/testws-u4esm/fallen_trees_origin-0tn0t) | ~4,761 imgs [S] | bbox [S] | fallen tree | [U] | — | [U] | A: fallen tree (largest; check view and license) |
| **Roboflow – Rubble Detection** | [link](https://universe.roboflow.com/rubble-project/rubble-detection) | ~437 imgs [S] | bbox [S] | rubble | [U] | earthquake | [U] (most Universe projects are CC BY 4.0) | A: rubble pile. B: `structural_collapse` |
| **Roboflow – Earthquake Damage Mapping / Damaged Building / DISASTER_detection** | [1](https://universe.roboflow.com/danny-george/earthquake-damage-mapping), [2](https://universe.roboflow.com/building-damaged/damaged-building), [3](https://universe.roboflow.com/asderids/disaster_detection-d9uqt) | 99 to a few hundred [S] | bbox [S] | collapsed, damaged, intact; fire, car crash | [U], mixed | earthquake | [U], likely CC BY 4.0 | A: damaged building, rubble. B: `structural_collapse` |
| **Roboflow – storm and hurricane projects** (EY Storm Damage, "hurricane damage 1", post-hurricane-matthew, EYxNASA) | [ey-storm-damage](https://universe.roboflow.com/ey-storm-damage), [quake](https://universe.roboflow.com/quake), [eyxnasa](https://universe.roboflow.com/eyxnasa) | 29–446 imgs each [S] | bbox [S] | damaged building (many are **satellite** from EY / NASA challenges) | mostly Sat [S/U] | hurricane | [U] | Low: mostly overhead |
| **Roboflow – debris projects** | [debris-rhnut](https://universe.roboflow.com/aswathy-dpap9/debris-rhnut), [debris-kywav](https://universe.roboflow.com/hilam/debris-kywav), [Debris DET](https://universe.roboflow.com/nam-trng/debris-det) | 157 to ~20k [S] | bbox [S] | "debris" (often **marine, space or road litter**, not storm) | [U] | mostly not storm | CC BY 4.0 [S] | Low unless inspected |
| **Roboflow – power line projects** | [powerlines-0qsir](https://universe.roboflow.com/damage-aled6/powerlines-0qsir/dataset/), [powerline-detection](https://universe.roboflow.com/college-2t4kc/powerline-detection), [ground-lines](https://universe.roboflow.com/ps-3z4y0/ground-lines-2bkdv) | [U] | bbox / seg [S] | intact power lines, insulators, faults | mostly UAV inspection [S] | none | CC BY 4.0 [S] | A: downed power line (**intact lines only**; weak) |
| **GDBDA** (Ground-level Detection in Building Damage Assessment) | [Liu et al. 2022, Remote Sensing 14(12):2763](https://www.mdpi.com/2072-4292/14/12/2763) | 856 phone/camera imgs → 3,918 crops [S] | **bbox** [S] | debris, collapse, spalling, crack | **G (smartphone)** | earthquake | **Availability and license [U]**: probably "on request" | A: damaged building, rubble. B: `structural_collapse` (**best ground-level match**) |
| **OHL-UK** (wooden utility poles) | [Strathclyde dataset page](https://pureportal.strath.ac.uk/en/datasets/data-for-ohl-uk-wooden-utility-pole-and-electrical-sign-corpus-wi/), [BMVC 2025](https://bmvc2025.bmva.org/proceedings/976/) | 4,570 imgs [S] | bbox + mask + **lean angle** [S] | wooden pole, warning sign | **G (Google Street View)** | none (intact poles) | [U]. Built from GSV imagery, so the **Google ToS likely restricts reuse** | B: `wire_pole_hazard` (leaning pole as a proxy). A: power line (partial) |
| **Incidents1M** (MIT CSAIL) | [github.com/ethanweber/IncidentsDataset](https://github.com/ethanweber/IncidentsDataset), [paper](https://arxiv.org/abs/2201.04236) | 977,088 imgs (1M version); 446,684 (ECCV 2020) [S] | **classification only**, multi-label: 43 incidents × 49 places [V/S] | tornado, damaged, collapsed, on fire, smoke, flooded, blocked… (full list [U]) | **mostly G** (web photos) | broad | Code/labels MIT [V]. **Images are URLs from the web, so the original owners hold copyright** [V]. Access via request form [V] | Good *source pool* for A and B. **Needs boxes** |
| **MEDIC** (QCRI) | [crisisnlp.qcri.org/medic](https://crisisnlp.qcri.org/medic/), [github.com/firojalam/medic](https://github.com/firojalam/medic) | 71,198 imgs [S] | classification: disaster type, informativeness, humanitarian, damage severity [S] | damage severity (none/mild/severe) | G (social media) | multi | **Conflicting**: figshare says CC BY 4.0, the download ships `LICENSE_CC_BY_NC_SA_4.0.txt` [S]. **Treat as NC** | Source pool for "damaged building". Needs boxes |
| **CrisisMMD** (QCRI) | [crisisnlp.qcri.org/crisismmd](https://crisisnlp.qcri.org/crisismmd), [paper](https://arxiv.org/abs/1805.00713) | ~18k images from 7 disasters of 2017 [S/U] | classification (informative, humanitarian, damage severity) | infrastructure damage, injured people | G (Twitter) | hurricanes, earthquakes, wildfires, floods | [U]. Twitter-derived; QCRI datasets are generally NC [U]. **X/Twitter terms apply** | Source pool only |
| **LADI v2** (MIT LL / FEMA Civil Air Patrol) | [MIT LL page](https://www.ll.mit.edu/r-d/projects/multi-label-dataset-and-classifiers-low-altitude-disaster-imagery), [HF](https://huggingface.co/datasets/MITLL/LADI-v2-dataset), [paper](https://arxiv.org/abs/2406.02780) | ~10k imgs [S] | multi-label classification (FEMA PDA labels) [S] | building damage levels, debris, flooding, roads | **Air** (oblique from small aircraft) | US declared disasters 2015–23 | CC BY 4.0 [S]. Commercial OK | Wrong viewpoint. Use only for pretraining or negatives |
| **AIDER / AIDERv2** | [Zenodo](https://zenodo.org/records/3888300), [AIDERv2 HF](https://huggingface.co/datasets/ckyrkou/AIDERv2), [paper](https://arxiv.org/abs/1906.08716) | 2,545 imgs (v1); 16,723 (v2) [S] | classification | collapsed building/rubble, fire/smoke, flood, traffic accident | UAV | multi | [U] (Zenodo record; check it). Images scraped from Google/Bing/YouTube, so third-party copyright | Wrong viewpoint |
| **C2A** | [github.com/Ragib-Amin-Nihal/C2A](https://github.com/Ragib-Amin-Nihal/C2A), [paper](https://arxiv.org/abs/2408.04922) | 10,215 imgs, 360k+ person boxes [V] | bbox (YOLO / COCO) [V] | person (5 poses) pasted onto AIDER scenes | UAV, **synthetic** | multi | **No license stated** [V], so not usable commercially | B: `bystander_survivor` (wrong viewpoint) |
| **RescueNet** | [paper (Sci Data 2023)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10733412/) | 4,494 imgs [U] | semantic segmentation + classification | debris, building damage levels, road-clear / road-blocked, tree | UAV | Hurricane Michael | CC BY 4.0 [S] | Has "road-blocked" and "debris", but from overhead |
| **FloodNet** | [paper](https://arxiv.org/abs/2012.02951), [DatasetNinja](https://datasetninja.com/floodnet) | 2,343 imgs (1,448 in Track 2) [S] | segmentation + VQA | flooded / non-flooded road and building, tree, vehicle | UAV | Hurricane Harvey | [U] | Low (flooding, overhead) |
| **CRASAR-U-DROIDs** | [paper](https://arxiv.org/abs/2407.17673) | 10 declared disasters [S] | building polygons + **road obstruction lines** | total/partial obstruction | UAV (georectified) | multi | [U] | B: `road_impassable` as a concept only |
| **xBD / xView2** | [xview2.org](https://xview2.org) | 22,068 tiles, 850k building polygons [S] | polygons + damage levels | building damage (4 levels) | **Sat** | 19 events incl. tornadoes | **CC BY-NC-SA** [S]. **Not commercial** | **Out of scope**: satellite top-down at ~0.3 m/px looks nothing like a phone photo, and NC |
| **TTPLA** | [github.com/R3ab/ttpla_dataset](https://github.com/R3ab/ttpla_dataset) | 1,100 imgs, 8,987 instances [S] | instance seg (COCO) [V] | tower types, power line | UAV [V] | none | **Apache-2.0** [V] | Intact lines from above. Weak for "downed" |
| **PLD-UAV / InsPLAD / STN-PLAD** | [PLD-UAV](https://datasetninja.com/pld-uav), [InsPLAD](https://huggingface.co/datasets/Voxel51/InsPLAD), [STN-PLAD](https://datasetninja.com/stn-plad) | hundreds to ~10k [S] | seg / bbox | power lines, insulators, components | UAV | none | PLD-UAV "other" [S]; others [U] | Weak |
| **COCO (person)** | [cocodataset.org](https://cocodataset.org) | ~64k imgs with person [U] | bbox, mask | person | G | none | Annotations CC BY 4.0; **images are Flickr, each under its own license, and COCO disclaims copyright** [S] | B: person baseline (the YOLO weights already know `person`) |
| **CrowdHuman** | [crowdhuman.org](https://www.crowdhuman.org), [paper](https://arxiv.org/abs/1805.00123) | 24k imgs, ~470k person boxes [U] | bbox (full, visible, head) | person under occlusion | G | none | **Custom Megvii license**; widely reported as non-commercial [U] | B: occluded people. **Avoid for commercial use** |
| **Milton-SV** | [DamageArbiter paper](https://arxiv.org/pdf/2603.14837) | 2,556 imgs [S] | classification (mild/moderate/severe) | — | **G (street view)** | Hurricane Milton 2024 | [U] (not confirmed public) | Good ground-level *eval* pool if released |
| **Roboflow – roof_sign_detector** | [link](https://universe.roboflow.com/wspace-wlvoi/roof_sign_detector) | ~730 imgs [S] | bbox [S] | signs on roofs | likely aerial [U] | — | [U] | B: SOS signs (wrong viewpoint) |

**Searched, but nothing ground-level was found:** gas-line ruptures, crushed propane tanks, low-hanging or downed wires seen from the street, and handwritten SOS signs held by people.

---

## 2. Per-class coverage matrix

Key:
- **++** usable ground-level boxes
- **+** some boxes, but small, the wrong viewpoint, or unverified
- **c** classification only (good source pool, but needs boxes)
- **·** nothing

| Class | D-Fire | Roboflow trees | Roboflow rubble / damage | GDBDA | OHL-UK | Incidents1M | MEDIC / CrisisMMD | LADI v2 | RescueNet | C2A | COCO person | TTPLA / PLD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **A** fallen tree | · | **+**/++ | · | · | · | c | c | c (Air) | + (UAV seg) | · | · | · |
| **A** damaged building | · | · | + | **++** | · | c | **c** (severity) | c (Air) | + (UAV) | · | · | · |
| **A** rubble pile | · | · | + | **++** (debris, collapse) | · | c | c | c | + (UAV "debris") | · | · | · |
| **A** downed power line | · | · | · | · | + (poles) | c [U] | · | · | · | · | · | + (intact, UAV) |
| **B0** bystander_survivor | · | · | · | · | · | c (people in scenes) | c ("injured or dead people") | · | · | + (UAV, synthetic) | **++** (generic person) | · |
| **B1** wire_pole_hazard | · | · | · | · | **+** (lean angle) | c [U] | · | · | · | · | · | + |
| **B2** structural_collapse | · | · | + | **++** | · | c | c | c | + | · | · | · |
| **B3** road_impassable | · | + (trees on road) | · | · | · | c ("blocked") [U] | · | c | + (UAV "road-blocked") | · | · | · |
| **B4** hazardous_leak | **++** (fire and smoke only) | · | + (fire in DISASTER_detection) | · | · | c (on fire, smoke) | · | · | · | · | · | · |

---

## 3. Gaps: classes that need our own labeling

| Class | Gap | Suggested sourcing |
|---|---|---|
| **Downed power line / wire_pole_hazard** | **Biggest gap.** No public ground-level boxes for downed, sagging or tangled wires or snapped poles. Wires are thin objects, which YOLO at 640 px handles poorly. | FEMA Media Library (public domain, many storm photos with lines down); NWS storm-survey photos posted on weather.gov event pages (federal works are generally public domain, but check each photo's credit); utility-company storm photos (ask permission); our app's confirmed labels; possibly synthetic composites. **Consider labeling the pole, or the whole "wire-down scene", rather than the wire itself.** |
| **Fallen tree (storm context)** | There are boxes, but many Roboflow sets are forest windthrow or small hobby projects of unknown viewpoint. | Filter the Roboflow sets by eye. Add Incidents1M "tornado" / "damaged" images and FEMA photos, pre-boxed by Grounding DINO with a human checking each box. |
| **Damaged building, rubble (tornado / wind)** | GDBDA is earthquake damage, which looks different from tornado damage (missing roofs, stripped siding, splintered wood rather than concrete). | FEMA and NWS photos from tornado events; Incidents1M "tornado"; MEDIC "severe" images. All need boxes. |
| **road_impassable** | Not a natural object. It is a judgement about a whole scene, so it is a poor fit for a box. Only aerial road-blocked labels exist. | Treat it as an **image-level tag** or a rule ("fallen tree / rubble box overlapping the road region"), not a YOLO class. |
| **hazardous_leak (gas, propane)** | Nothing public. Gas leaks are mostly invisible in a photo. | Keep fire and smoke (D-Fire). Drop or postpone gas and propane. |
| **bystander_survivor / SOS signs** | Generic `person` is solved by COCO. "Survivor vs bystander" is not visible in a photo, and there is no data for handwritten SOS signs held at ground level. | Don't train it. See the taxonomy note. |

**Sourcing notes**
- **FEMA Media Library:** 49k+ photos since 1980, US-government works, public domain in the US. See the [usage guidelines](https://www.fema.gov/photo-video-audio-use-guidelines) and [Wikipedia](https://en.wikipedia.org/wiki/FEMA_Photo_Library). Some photos credit non-federal photographers, so check the credit line.
- **NWS Damage Assessment Toolkit:** survey points with photos are viewable on the [DAT](https://disasters-geoplatform.hub.arcgis.com/pages/noaa-damage-assessment-toolkit-dat). Bulk photo export and reuse terms are **[U]**.
- **Social media:** X/Twitter and Facebook terms forbid redistributing content and limit training uses. Keep social media for research or evaluation only, or ask the photo owner.
- **Our own flywheel:** confirmed boxes from the app are the cleanest long-term source. They need consent wording in the app and face/plate blurring before photos join the training set.
- **Synthetic data:** paste-in composites of wires, poles and trees onto street backgrounds. This is cheap, but there is a gap between how synthetic and real photos look. Use it for pretraining, not evaluation.

---

## 4. Recommended starter recipe (v0 model)

**Target classes (hybrid):** `fallen_tree`, `damaged_building`, `rubble_debris`, `downed_line_or_pole`, `fire_smoke`.

| Step | Source | Remap | Rough count |
|---|---|---|---|
| 1 | **D-Fire** | fire + smoke → `fire_smoke` (or keep 2 classes) | Subsample ~3–5k, so it doesn't swamp the other classes. Keep ~1k of D-Fire's 9.8k "none" images as negatives. |
| 2 | **Roboflow fallen-tree sets** (3–5 projects that are CC BY or PD and ground-level) | trunk / treefall / fallen tree → `fallen_tree`; drop root and palm sub-classes or merge them | ~1–3k after removing duplicates and aerial images |
| 3 | **Roboflow rubble and damaged-building sets + GDBDA** (if the authors share it) | debris → `rubble_debris`; collapse, damaged → `damaged_building`; drop crack and spalling | ~1–2k |
| 4 | **Ground-level photos auto-labeled, then human-reviewed** from Incidents1M (tornado, damaged, collapsed, blocked) and FEMA | Grounding DINO (Apache-2.0) or OWLv2 with text prompts ("fallen tree", "downed power line", "collapsed house", "pile of debris") → a person checks every box in Roboflow, CVAT or Label Studio. SAM is optional, to tighten boxes | Aim for **~1k `downed_line_or_pole`** and ~1k extra tornado-damage images |
| 5 | Background / negatives | Ordinary street photos with no damage (COCO, or our own) | ~10% of the set |

**Notes on converting labels**
- Incidents1M, MEDIC and LADI give **one label per image**. That label only helps choose *which* photos to box. It cannot be turned into boxes directly.
- Auto-labeling is fine for trees and rubble, where the outline is clear. It is unreliable for thin wires: expect most of those boxes to need human correction.
- Merging rubble and damaged building in the first model is also an option. People will confuse them, and so will the model.
- Remove duplicates across the Roboflow sets (perceptual hashing). Many Universe projects are forks of each other.
- **Augmentation:** the brainstorm's Blur, MotionBlur, Mosaic and MixUp are reasonable. Also add HSV and brightness jitter for overcast storm light, and random rain or JPEG noise.

**Validation strategy**
- **Hold out 300–500 real ground-level tornado and wind-storm photos.** Take them from FEMA and NWS, from events that are *not* in training, and box them by hand twice. Report mAP50 per class on this set only. Validation splits drawn from Roboflow will overstate accuracy.
- Split by **disaster event**, not by image, so that near-duplicate photos from one storm don't leak between train and validation.
- Track the **false-negative rate on downed lines** as a separate safety metric. For example, also report recall at a low confidence threshold.
- Once the app ships, the confirmed labels become a rolling validation set.

---

## 5. Taxonomy note (design input, not a decision)

**Trainability ranking:** A ≈ hybrid > B.
- A's classes are visible, box-shaped objects with at least some public data.
- B mixes in things that aren't objects (`road_impassable`), things that can't be seen (gas leaks), and a class we can't verify from a photo (`survivor`).

**Hybrid suggestion.** Keep A. Rename *downed power line* to *downed line or pole*, which takes B1's useful scope. Add `fire_smoke`, which takes the part of B4 that has data. Make "road blocked" a **tag on the report**, not a class.

**`bystander_survivor` in a consumer neighbor app.** Flag this in the critique:
- **Privacy.** The app would be auto-boxing people in public photos, including injured people, and pinning them on a shared map with exact coordinates. That clashes with the PRD tone ("never at the expense of people who were hurt"). It also raises consent and retention problems, and it makes the photos training data.
- **SAR liability.** A consumer model will miss people, especially people partly buried, lying down or in low light. A UI that says "no survivors detected" could discourage someone from calling 911. Any SAR feature should say "call 911" and never imply that a scene has been cleared.
- **Gameable and upsetting.** Votes on whether someone is a "survivor" are an odd social interaction.
- **Data.** There is no ground-level survivor data. Generic `person` (COCO) can't tell a survivor from a bystander.
- **Better default.** Detect `person` only to **blur faces** before sharing. Don't label people as a debris class.

---

## 6. Licensing notes and red flags

1. **Ultralytics AGPL-3.0.** YOLOv8 and YOLO11 code and weights are AGPL-3.0. Ultralytics says closed-source or commercial deployment, *including fine-tuned models embedded in apps*, needs an **Enterprise License** ([docs](https://docs.ultralytics.com/), [licensing](https://www.ultralytics.com/request-license)). Decide early between three paths:
   - open-source the app under AGPL,
   - buy the Enterprise License, or
   - use a permissively licensed detector, such as YOLOX (Apache-2.0), RT-DETR in other repos, or Apple's Create ML object detector.
2. **Non-commercial data.**
   - xBD: CC BY-NC-SA.
   - MEDIC: ships an NC-SA license file.
   - CrisisMMD: likely NC [U].
   - CrowdHuman: custom license [U].
   - C2A: no license, so treat it as all rights reserved.

   Even for a free app, "non-commercial" is ambiguous. Avoid these for production weights.
3. **Twitter/X-derived data** (CrisisMMD, much of MEDIC). Platform terms limit redistribution, and the photos belong to the people who posted them. Use them for research or evaluation only.
4. **Web-scraped URL lists** (Incidents1M, AIDER). The dataset license (MIT) covers the labels, not the photos. Commercial training on the images is a copyright gray area.
5. **Google Street View-derived data** (OHL-UK, many street-view damage studies). Google Maps ToS restricts using imagery to train models. Treat these as off-limits for production.
6. **Roboflow Universe.** Licenses are set per project by uploaders and often aren't checked. Images may be scraped. Keep a spreadsheet of project, version, license and attribution text, and include the attributions in the app's acknowledgements for CC BY data.
7. **Safe bets:**
   - D-Fire (CC0) [S]
   - TTPLA (Apache-2.0) [V]
   - LADI v2 (CC BY 4.0) [S]
   - RescueNet (CC BY 4.0) [S]
   - FEMA / NWS federal photos (public domain, check each credit)
   - our own users' photos (with consent)

---

## 7. Sources

**Datasets: ground level**
- D-Fire: https://github.com/gaiasd/DFireDataset · https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11398105/
- Incidents / Incidents1M: https://github.com/ethanweber/IncidentsDataset · https://arxiv.org/abs/2201.04236 · https://arxiv.org/abs/2008.09188
- MEDIC: https://crisisnlp.qcri.org/medic/ · https://arxiv.org/abs/2108.12828 · https://figshare.com/articles/journal_contribution/MEDIC_a_multi-task_learning_dataset_for_disaster_image_classification/21597078
- CrisisMMD: https://crisisnlp.qcri.org/crisismmd · https://arxiv.org/abs/1805.00713
- GDBDA (LA-YOLOv5): https://www.mdpi.com/2072-4292/14/12/2763
- OHL-UK: https://pureportal.strath.ac.uk/en/datasets/data-for-ohl-uk-wooden-utility-pole-and-electrical-sign-corpus-wi/ · https://bmvc2025.bmva.org/proceedings/976/
- Milton-SV / DamageArbiter: https://arxiv.org/pdf/2603.14837
- CrowdHuman: https://arxiv.org/abs/1805.00123 · https://www.crowdhuman.org
- COCO: https://cocodataset.org

**Datasets: Roboflow Universe** (none of these could be opened; details come from search snippets)
- Fallen trees:
  - https://universe.roboflow.com/visual-deformity/fallen-trees-pka1c
  - https://universe.roboflow.com/steve-chun/fallen-trees-1dfmg
  - https://universe.roboflow.com/overflow-thaap/fallen-trees-with-palms
  - https://universe.roboflow.com/object-detection-oudof/fallen_trees_all_trunk
  - https://universe.roboflow.com/testws-u4esm/fallen_trees_origin-0tn0t
  - https://universe.roboflow.com/project-w4c4g/damaged-tree-detection
- Rubble and damaged buildings:
  - https://universe.roboflow.com/rubble-project/rubble-detection
  - https://universe.roboflow.com/danny-george/earthquake-damage-mapping
  - https://universe.roboflow.com/building-damaged/damaged-building
  - https://universe.roboflow.com/asderids/disaster_detection-d9uqt
- Storm and hurricane:
  - https://universe.roboflow.com/ey-storm-damage
  - https://universe.roboflow.com/quake
  - https://universe.roboflow.com/eyxnasa
  - https://universe.roboflow.com/detr-2bavb/storm-kaulv
- Debris:
  - https://universe.roboflow.com/aswathy-dpap9/debris-rhnut
  - https://universe.roboflow.com/hilam/debris-kywav
  - https://universe.roboflow.com/nam-trng/debris-det
- Power lines:
  - https://universe.roboflow.com/damage-aled6/powerlines-0qsir/dataset/
  - https://universe.roboflow.com/college-2t4kc/powerline-detection
  - https://universe.roboflow.com/ps-3z4y0/ground-lines-2bkdv
- Roof signs: https://universe.roboflow.com/wspace-wlvoi/roof_sign_detector

**Datasets: aerial, drone or satellite** (listed so you can see why each is out of scope)
- LADI v2: https://www.ll.mit.edu/r-d/projects/multi-label-dataset-and-classifiers-low-altitude-disaster-imagery · https://huggingface.co/datasets/MITLL/LADI-v2-dataset · https://arxiv.org/abs/2406.02780
- AIDER: https://zenodo.org/records/3888300 · https://huggingface.co/datasets/ckyrkou/AIDERv2 · https://arxiv.org/abs/1906.08716
- C2A: https://github.com/Ragib-Amin-Nihal/C2A · https://arxiv.org/abs/2408.04922
- RescueNet: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10733412/
- FloodNet: https://arxiv.org/abs/2012.02951
- CRASAR-U-DROIDs: https://arxiv.org/abs/2407.17673
- xBD: https://xview2.org · https://hyper.ai/en/datasets/13272
- TTPLA: https://github.com/R3ab/ttpla_dataset · https://arxiv.org/abs/2010.10032
- PLD-UAV / STN-PLAD / InsPLAD: https://datasetninja.com/pld-uav · https://datasetninja.com/stn-plad · https://huggingface.co/datasets/Voxel51/InsPLAD

**Imagery sources and tools**
- FEMA Media Library: https://en.wikipedia.org/wiki/FEMA_Photo_Library · https://www.fema.gov/photo-video-audio-use-guidelines
- NWS Damage Assessment Toolkit: https://disasters-geoplatform.hub.arcgis.com/pages/noaa-damage-assessment-toolkit-dat
- Grounding DINO / Autodistill / OWLv2: https://roboflow.com/model-licenses/grounding-dino · https://pypi.org/project/autodistill-grounding-dino/0.1.0/
- Ultralytics licensing: https://docs.ultralytics.com/ · https://www.ultralytics.com/request-license
