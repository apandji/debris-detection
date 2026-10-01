# AGENTS.md

Guidance for coding agents working on this repo.

## Purpose

**Debris Mapper**: neighbors photograph storm debris, a (mocked) YOLO model suggests what's in the photo, and people confirm or reject those suggestions. Reports are pinned on a shared map. It's social: anyone can open any report, vote on its detections, and leave voice notes. Human-confirmed labels later become training data.

Debris classes (PoC): fallen tree, damaged building, rubble pile, downed power line. Don't add classes unless asked.

See `PRD.md` for product intent and tone (neighborly, light, never at the expense of people who were hurt).

## Current state

- **Primary product: native iOS app** in `ios/` (SwiftUI, iOS 17+, iPhone only, portrait).
- **Status: demo scaffold for design critique.** Everything that would need a server is mocked on-device.
- `index.html` + `api/annotations.js` are the earlier web labeling PoC. Treat them as legacy reference; don't extend them unless asked.

### What's real vs mocked (iOS)

| Piece | State |
|---|---|
| Camera capture (AVFoundation) | Real. Simulator has no camera, so it falls back to the photo library picker. |
| Location | Real device GPS at capture time. Library photos prefer EXIF GPS. **Posting is blocked without a location.** |
| YOLO detection | **Mock** (`MockDetector`): 1–3 random boxes/classes after ~0.9 s. |
| Voting (confirm / reject) | Real UI; stored **locally only**. |
| Voice notes | Real recording/playback (AVAudioRecorder, .m4a); stored **locally only**. |
| "Other neighbors" | **Fake.** Five seeded reports scattered around your first location fix, with fake votes. No photos (placeholder shown). |
| Backend / sync / accounts | **None.** `ReportStore` persists JSON + files in the app's Documents folder. Identity is a per-device UUID shown as "You". |

## Layout

```
ios/
  DebrisMapper.xcodeproj      # Xcode 16 project; uses a synced folder, so new files in DebrisMapper/ are picked up automatically
  project.yml                 # XcodeGen fallback only (if the .xcodeproj won't open)
  DebrisMapper/
    App/DebrisMapperApp.swift # @main, RootView with two tabs: Capture, Map
    Models/Report.swift       # DebrisClass, BoundingBox, Detection (+votes), VoiceNote, Report
    Services/
      ReportStore.swift       # @Observable store, the single source of truth + demo seed. Swap point for a real backend.
      MockDetector.swift      # Fake YOLO. Swap point for Core ML.
      LocationManager.swift
      CameraModel.swift
      VoiceNotes.swift        # VoiceRecorder + VoicePlayer
    Views/
      Capture/CaptureView.swift   # Tab 1: full-screen camera, shutter, library button, location pill
      Capture/ReviewView.swift    # Post-shutter: suggestions → confirm/reject → Post
      Map/ReportMapView.swift     # Tab 2: MapKit pins, tap → detail sheet
      Report/ReportDetailView.swift # Photo + boxes, community votes, voice notes
      Components/DetectionOverlay.swift # DetectionPhoto (boxes on image), VoteButtons
index.html, api/, vercel.json # legacy web PoC
PRD.md
```

## How to run (iOS)

1. Open `ios/DebrisMapper.xcodeproj` in Xcode 16 or later.
2. Target **DebrisMapper** → Signing & Capabilities → pick your Team (bundle id `com.example.debrismapper`; change it if it collides).
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

- A YOLO/mock suggestion is **never** ground truth on its own. `Detection.votes` (userID → confirm/reject) is the human signal.
- The poster's confirm/reject in Review is just their vote; other neighbors vote the same way on the detail sheet.
- Never auto-vote, never overwrite someone's vote, never re-run detection over a posted report.
- How votes roll up into a training label (majority? threshold?) is **undecided**. Don't invent a rule; ask.

## Location

- Mandatory for posting (PRD §12). Capture uses device GPS at the shutter; library picks use EXIF, then device GPS.
- MapKit only, no GIS stack. Pins are exact coordinates for now (fuzzing is an open question).

## What not to overbuild

- No real YOLO / Core ML model, training loop, or dataset export yet.
- No backend, auth, or accounts until the user picks a stack (see open questions).
- No feed, comments-as-text, profiles, notifications, moderation, or multi-photo queues unless asked.
- No AR revisit (PRD stretch goal).

## Open questions (ask the user before building)

1. Shared backend for real multi-user data: CloudKit public DB vs Supabase/Firebase vs custom?
2. Identity: anonymous device IDs, Sign in with Apple, or display names?
3. Can voters also **change** a label or add/move boxes, or only confirm/reject (current)?
4. Should rejected suggestions still be posted (current: yes, with the poster's reject vote) or dropped?
5. Vote → ground-truth rule (e.g. ≥2 confirms and confirms > rejects)?
6. Voice notes: length limit? Transcription? Moderation?
7. Map pin precision (exact vs fuzzed near homes); clustering/filters?
8. PRD §6 lists "social feed, comments" and accounts as non-goals. Voting + voice notes now make it social; update the PRD to match.
