# AGENTS.md

Guidance for coding agents working on this repo.

## Team (who owns what)

Two Claude sessions work on this repo, both on Andrew's Mac. Stay in your lane; anything cross-cutting goes to the orchestrator.

| Agent | Session | Owns | Branch |
|---|---|---|---|
| **Orchestrator + model dev** | `LOCAL MODEL TRAINER` (Apple Silicon/MPS, `training/.env` holds the Roboflow key) | `AGENTS.md`, `PRD.md`, planning, reviewing and merging into `main`; `training/`, `research/`, model releases | `model-local` |
| **iOS dev** | `iOS DEV` (Xcode) | `ios/` | `ios-dev` |

- **`main` is the integration branch** (since 2026-10-06). Branch off `main`, push your branch, open a PR into `main`, and tell the orchestrator. Only the orchestrator merges.
- Retired: `ios-scaffold` (old integration branch, merged into `main`) and `model-dev` (cloud model agent, finished 2026-10-02, merged).
- Model versions: `training/manifests/models.yaml` is the registry. Each version is a private GitHub Release `model-<version>` (zipped `.mlpackage` + `best.pt`); `ios/fetch-model.sh` downloads it. The package carries its version (`versionString`), and the app shows it.
- **The contract between iOS and model** is the Core ML model: file `DebrisDetector.mlpackage`, 640×640 input, NMS baked in, class names in this order: `fallen_tree, damaged_building, rubble_debris, downed_line_or_pole, fire_smoke`. Changing it means telling the orchestrator first.
- Images and labels live in the Roboflow project **`pandji/storm-debris-detection`** (private). Git holds code, registries, and manifests only, never images.

## Purpose

**Debris Mapper**: neighbors photograph storm debris, an on-device YOLO model (Core ML) suggests what's in the photo, and people confirm or reject those suggestions. Reports are pinned on a shared map. It's social: anyone can open any report, vote on its boxes, fix a label or box, add a box, and leave voice notes. Human-confirmed labels later become training data.

Debris classes (the model contract): fallen tree, damaged building, rubble or debris, downed line or pole, fire or smoke. Don't add classes unless asked.

See `PRD.md` for product intent and decisions. Tone: **neighborly and a little playful** ("Squinting at your photo…"), never at the expense of people who were hurt, and always plain about safety.

## Current state

- **Primary product: native iOS app** in `ios/` (SwiftUI, iOS 17+, iPhone only, portrait).
- **Status: demo scaffold for design critique.** Everything that would need a server is mocked on-device.
- `index.html` + `api/annotations.js` are the earlier web labeling PoC. Treat them as legacy reference; don't extend them unless asked.

### What's real vs mocked (iOS)

| Piece | State |
|---|---|
| Camera capture (AVFoundation) | Real. Simulator has no camera, so it falls back to the photo library picker. |
| Location | Real device GPS at capture time. Library photos prefer EXIF GPS. **Posting is blocked without a location.** |
| YOLO detection | **Real, on-device**: `CoreMLDetector` runs the bundled `DebrisDetector.mlpackage` (v0) via Vision. Cutoff 0.25, 0.15 for downed lines. Each suggested box stores `modelVersion`; Review shows "Model v0". Falls back to `MockDetector` (1–3 random boxes) when the model isn't fetched. |
| Voting (yes / no) and box editing | Real UI; stored **locally only**. |
| Voice notes | Real recording/playback (AVAudioRecorder, .m4a, **30 s cap**); stored **locally only**. |
| "Other neighbors" | **Fake.** Five seeded reports with friendly handles scattered around your first location fix, with fake votes. No photos (placeholder shown). |
| Backend / sync | **None (deferred until after critique).** `ReportStore` persists JSON + files in the app's Documents folder. |
| Identity | Anonymous. Per-device UUID + a friendly three-word handle (`FriendlyName`, e.g. `fire-onyx-support`), shown with "(you)". No accounts. |

## Layout

```
ios/
  DebrisMapper.xcodeproj      # Xcode 16 project; uses a synced folder, so new files in DebrisMapper/ are picked up automatically
  project.yml                 # XcodeGen fallback only (if the .xcodeproj won't open)
  fetch-model.sh              # Downloads release model-<version> (default v0) into DebrisMapper/ML/
  DebrisMapper/
    App/DebrisMapperApp.swift # @main, RootView with two tabs: Capture, Map
    Models/Report.swift       # DebrisClass, BoundingBox, Detection (+votes), VoiceNote, Report
    Services/
      ReportStore.swift       # @Observable store, the single source of truth + demo seed. Swap point for a real backend.
      MockDetector.swift      # `Detector` protocol, `Detectors.current`, and the mock fallback
      CoreMLDetector.swift    # Vision + DebrisDetector.mlpackage (labels.first, per-class cutoffs)
      LocationManager.swift
      CameraModel.swift
      VoiceNotes.swift        # VoiceRecorder + VoicePlayer
    ML/DebrisDetector.mlpackage # git-ignored; installed by ios/fetch-model.sh
    Views/
      Capture/CaptureView.swift   # Tab 1: full-screen camera, shutter, library button, location pill
      Capture/ReviewView.swift    # Post-shutter: suggestions → confirm/reject → Post
      Map/ReportMapView.swift     # Tab 2: MapKit pins, tap → detail sheet
      Report/ReportDetailView.swift # Photo + boxes, community votes, voice notes
      Components/DetectionOverlay.swift # DetectionPhoto (boxes on image), VoteButtons
      Components/BoxEditorView.swift    # Move/resize/relabel/add boxes (used by Review and Report)
research/                     # Model + dataset research (not app code)
training/                     # Dataset registry (sources.yaml) + fetch/merge/train/export scripts. See training/README.md
index.html, api/, vercel.json # legacy web PoC
PRD.md
```

## How to run (iOS)

1. Fetch the model: `ios/fetch-model.sh` (needs `gh` signed in to the repo). Skip it and the app uses `MockDetector`.
2. Open `ios/DebrisMapper.xcodeproj` in Xcode 16 or later. Signing is set to Andrew's team (`4L26YVZYX3`), bundle id `com.apandji.debrismapper`; others pick their own Team and bundle id in Signing & Capabilities.
3. Run on an iPhone (iOS 17+) for camera + GPS. In the Simulator, set a location (Features → Location → e.g. Apple) and use the library button.
4. To reset demo data, delete the app (seed + reports are local).

No CocoaPods/SPM dependencies. Keep it that way unless asked.

## Conventions

- **SwiftUI + Apple frameworks only** (AVFoundation, CoreLocation, MapKit, PhotosUI). No third-party UI kits, map SDKs, or backend SDKs unless the user asks.
- **Design: minimal and as Apple as possible.** System fonts, SF Symbols, system colors, materials, `List`/inset-grouped, standard toolbars/sheets/detents, haptics via `sensoryFeedback`. No custom brand palette, gradients, or bespoke components where a system one exists. Follow the HIG; copy is short and plain (sentence case in body text, title case for buttons).
- State: `@Observable` classes injected with `.environment(...)`. `ReportStore` is the only place reports are mutated.
- Swift language mode 5 (to keep the scaffold free of strict-concurrency friction). Deployment target iOS 17.
- Boxes are normalized (`x, y, w, h` in 0–1, top-left origin), same as the web PoC.
- Keep files small and grouped by feature as above. No extra docs, design systems, or sample assets unless asked.

## Annotations are ground truth (only when humans say so)

- A YOLO/mock suggestion is **never** ground truth on its own. `Detection.votes` (userID → yes/no) is the human signal.
- **Confirmed = 2 yes votes** (`Detection.confirmThreshold`). Only confirmed boxes become training labels.
- The poster's yes/no in Review is just their vote; neighbors vote the same way on the report sheet.
- Rejected suggestions are still posted, carrying the poster's no, so neighbors can disagree.
- **Edits never overwrite.** In Review (the poster's unposted draft) edits apply in place. On a posted report, a neighbor's label/box change becomes a **new box** (`source: .person`, `revisionOf: originalID`) with the editor's yes, and the editor's vote on the original becomes no. Added boxes carry the adder's yes. Posted boxes can't be deleted; vote them down.
- Drawing or fixing a box is the only implied vote. Never auto-vote anything else, never change someone else's vote, never re-run detection over a posted report.

## Location

- Mandatory for posting (PRD §12). Capture uses device GPS at the shutter; library picks use EXIF, then device GPS.
- MapKit only, no GIS stack. Pins are exact coordinates for now (fuzzing is an open question).

## Voice notes

- Max 30 s (`VoiceRecorder.maxDuration`); recording auto-stops and saves at the cap. Clips under 0.5 s are discarded.

## What not to overbuild

- The app runs the Core ML model on-device; don't add server-side inference. Training tooling lives in `training/` (Python, separate from the app; v0 classes: fallen_tree, damaged_building, rubble_debris, downed_line_or_pole, fire_smoke). Keep `sources.yaml` the single dataset registry; never train on `role: test` or unreviewed prelabels. Direction is on-device Core ML (offline after storms); see `research/` for the model brief and dataset research. `Detector` (in `MockDetector.swift`) is the swap point; new versions ship as releases, not in git.
- No backend or auth until the user picks a stack (deferred until after critique). No accounts ever without asking; identity is anonymous handles.
- No feed, comments-as-text, profiles, notifications, moderation, or multi-photo queues unless asked.
- No AR revisit (PRD stretch goal).

## Open questions (ask the user before building)

1. Shared backend for real multi-user data: CloudKit public DB vs Supabase/Firebase vs custom? (deferred until after critique)
2. Map pin precision (exact vs fuzzed near homes); clustering/filters?
3. Moderation for public photos and voice notes?
4. Model taxonomy: keep the 4 debris classes or move toward the SAR-style 5 in `research/model-brief.md` (includes people/survivors, which raises privacy questions)?
