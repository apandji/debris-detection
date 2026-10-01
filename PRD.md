# PRD outline — Debris Mapper

Status: draft outline (decisions filled 2026-09-29; social + iOS decisions 2026-10-01)  
Product working name: **Debris Mapper**  
Related: native iOS scaffold in `ios/` (primary); legacy web PoC `index.html`

---

## 1. One-liner

**Debris Mapper** is a lightweight iPhone app where neighbors photograph and tag storm debris — turning “it just sits in the camera roll” into a shared, place-aware map of what’s out there after bad weather. It’s social: anyone can open a report, vote on what the model spotted, fix a box, or leave a voice note.

## 2. Inspiration & tone

- Inspired by people walking around after tornadoes / storms, taking pictures of fallen trees, damaged roofs, rubble, downed lines — and those photos never leaving the phone.
- The product should bring **levity and joy**, not disaster-tourism or heavy civic bureaucracy.
- Feel: neighborly, slightly playful, clear, quick. Not a government portal. Not a grim ops dashboard.
- Humor is welcome in copy and UI personality; never at the expense of people who were hurt or lost homes.

## 3. Problem

After a storm, neighbors already document debris with their phones. That effort is wasted:

1. Photos stay private in camera rolls.
2. There’s no easy way to label *what* is in the photo.
3. There’s no shared, place-aware picture of “what’s out there on our block.”

Separately, better debris detection models need real human-confirmed labels — but collection has to feel worth doing for ordinary people, not only for ML engineers.

## 4. What v1 is

**v1 is a technical exploration**, not a polished consumer launch.

Prove a thin end-to-end featureset:

1. **YOLO detections** on a storm debris photo (real model path; mock is only a stand-in until then).
2. **Community review** — the poster and any neighbor can vote yes/no on each box, fix a label, move/resize a box, or add one. A box counts as **confirmed** at **2 yes votes**.
3. **Upload / persist** the photo + boxes + votes + **mandatory location**.
4. **Map** — anyone can see submitted debris reports as equal neighbor pins/markers (no privileged roles).
5. **Voice notes** — anyone can leave a short (≤30 s) voice note on a report.

Platform: **native iOS (SwiftUI)**, two tabs — Capture and Map. The web PoC is legacy reference.

### Stretch goal (post-v1 exploration)
- **AR revisit loop:** navigate people to a reported spot, confirm whether debris is still there / gone, and optionally take a new photo to update the report.

## 5. Goals

### Exploration goals (v1)
- Prove YOLO → correct-in-UI → upload → visible-on-map works on a phone.
- Validate that neighbors will confirm/correct debris labels in the field.
- Learn which classes people can tag confidently.
- Prove **mandatory location** capture (EXIF and/or device GPS) is reliable enough for map pins.

### Product goals (tone / adoption, even in exploration)
- Keep “snap → tag → upload” fast on a phone.
- Make the map the payoff: your photo left the camera roll and showed up for everyone.
- Keep the experience light enough that people actually open Debris Mapper after a storm.

## 6. Non-goals (for now)

- Official emergency-management tooling or 911 integration.
- User accounts, roles, moderation queues, or “organizer vs resident” privilege tiers (v1: all neighbors equal; identity is an anonymous handle).
- Text comments, a social feed, profiles, or neighborhood chat. (Social in v1 = votes, box fixes, and voice notes on a report.)
- Full GIS stack / routing / parcel data (map is for seeing reports, not a planning system).
- Large training platform / model registry before the upload→map loop is real.
- Shipping the AR revisit experience in v1 (stretch only).

## 7. Users & visibility

### Who uses it
- **Neighbors / residents** after a storm: walk the block, take a photo, tag what they see, upload, see it on the map.

### Identity
- **Anonymous.** Each device gets a friendly three-word handle (e.g. `fire-onyx-support`). No sign-up, no profiles.

### Who can see reports
- **Everyone.** All neighbors are equal — no private submissions, no organizer-only layer in v1.
- Assume public (or broadly shared) photo + location + labels. Privacy copy should say so clearly before upload.

Assume: one hand, outdoor light, spotty connectivity, emotional fatigue after severe weather. UI must be thumb-friendly and forgiving.

## 8. Core experience loop

1. Open Debris Mapper → **Capture** tab (camera).
2. Take photo (or pick from camera roll).
3. **Location** attaches automatically (required — device GPS at the shutter; EXIF for library photos).
4. See suggested debris boxes (YOLO; mock only until the real model is wired).
5. Vote ✓/✕ on each, fix labels/boxes, or add a box. Rejected suggestions are still posted (with the poster’s no) so neighbors can disagree.
6. Post. Land on the **Map** tab, zoomed to the new pin.
7. Neighbors open the pin, vote, fix boxes, and leave voice notes. Two yes votes confirm a box.
8. Done — back to walking the block.

The emotional beat after upload should reinforce usefulness and lightness (“it’s on the map”) rather than clinical ML language.

## 9. Debris classes (starting set)

Keep the current PoC set until field testing says otherwise:

| Class | Notes |
|---|---|
| Fallen tree | Common, easy for neighbors to recognize |
| Damaged building | Sensitive — copy should stay respectful |
| Rubble pile | Broad; may need clearer examples |
| Downed power line | Safety-sensitive — never encourage approaching lines |

Open: merge/split classes? Add flooded street, debris on road, etc.?

## 10. Product principles

1. **Exploration over ceremony.** v1 proves the loop; polish follows evidence.
2. **Confirmed only.** Unconfirmed YOLO suggestions are never ground truth.
3. **Joy without denial.** Light tone; still honest that storms suck.
4. **Phone-native.** Camera, big taps, short copy, works in sunlight.
5. **Location is mandatory.** No map pin, no upload.
6. **Equal neighbors.** Same submit rights, same visibility — no special roles in v1.
7. **Don’t overbuild.** Prefer the smallest stack that proves YOLO + edit + upload + map.

## 11. Functional requirements (outline)

### Must have (v1 exploration)
- [x] Camera capture + upload from camera roll (iOS scaffold)
- [ ] YOLO suggestions on the photo (real model path; mock acceptable only as interim — mock in scaffold)
- [x] Bounding-box review: vote yes/no / edit label / move / resize / add (scaffold)
- [x] Neighbor fixes keep the original box and its votes (a fix is a new box, never an overwrite)
- [x] Clear confirmed (≥2 yes) vs suggestion state
- [x] Voice notes on a report, ≤30 s (scaffold; stored on-device only)
- [ ] **Mandatory location** before submit (EXIF GPS and/or device geolocation)
- [ ] Persist photo + boxes + votes + voice notes + location to a **shared** backend (scaffold is on-device only)
- [x] **Map view** of all reports (everyone equal)
- [ ] Submit success / failure feedback (needs real backend)
- [x] Native iPhone app

### Nice to have (still v1 if cheap)
- [x] Tap map pin → see photo + labels
- [ ] Lightweight “N reports on the map” moment after upload
- [ ] Offline queue + sync when back online
- [x] Safety copy near downed-power-line class

### Stretch (explicitly not v1)
- [ ] AR navigation to an existing report
- [ ] On-site confirm: still there / cleared
- [ ] Follow-up photo that updates or closes the report

## 12. Geospatial

**Decision:** location is **mandatory** for every upload.  
**Decision:** reports are visible to **all neighbors equally** on a shared map.

### Implementation notes (outline)
- Prefer JPEG EXIF GPS when present.
- If EXIF missing, require device geolocation (with a clear permission prompt).
- If neither available → cannot submit (explain why, offer retry).
- Map shows pins/markers for reports; precision/blurring TBD but default is honest lat/lng for exploration unless field testing demands fuzzing.

### Still open (implementation detail, not product direction)
- Exact map library / provider.
- Pin clustering, filters by class, time window.
- Whether photos are full-res public or thumbnail + lightbox.

## 13. Success metrics

### Exploration (primary for v1)
- End-to-end path works on phone: detect → adjust → upload with location → appears on map.
- % of attempted submits blocked only for “good” reasons (no location / no confirmed boxes).
- Time from open → successful upload for a simple photo (target: &lt; 60s).

### Data quality
- Confirmed boxes per photo.
- Correction rate vs YOLO suggestions.
- Class confusion (which labels get changed most).

### Joy / levity (soft)
- People understand “it’s on the map for everyone” and still choose to upload.
- Copy/UI feedback that lands as warm, not corny (validate in phone tests).

## 14. Risks & constraints

- **Tone risk:** too cute after real damage → feels tone-deaf; too serious → nobody opens it.
- **Safety:** downed power lines / unstable structures — never encourage unsafe approach (especially later AR “walk to pin”).
- **Privacy:** v1 is public-by-default (photo + location). Must be explicit in UI; may limit willingness to photograph damaged homes.
- **Connectivity:** post-storm networks are bad; design for flaky upload.
- **Mandatory GPS:** indoor/camera-roll photos without EXIF will force device location (which may not match where the debris was).
- **Cold start:** without real persistence + map, neighbor effort is discarded.

## 15. Phased roadmap (suggested)

### Phase 0 — Labeling PoC (mostly done)
- Mock YOLO UI, EXIF read, Vercel HTTPS path for phone testing.

### Phase 1 — v1 technical exploration
- Real or stand-in YOLO in the loop.
- Confirm/adjust boxes; mandatory location; persist uploads.
- Shared map of all neighbor reports (equal visibility).
- Tone pass so the exploration still feels like Debris Mapper, not a lab tool.

### Phase 2 — Hardening from field use
- GPS fallback quality, pin UX, safety/privacy copy, offline submit, class tweaks.

### Phase 3 — Model improvement loop
- Export confirmed labels → retrain → better suggestions → less correction time.

### Phase 4 — Stretch: AR revisit
- Navigate to a pin, confirm gone/still there, optional new photo, update map state.

## 16. Decisions log

| Topic | Decision |
|---|---|
| Working name | **Debris Mapper** (for now) |
| v1 purpose | Technical exploration proving YOLO + label/position adjust + upload + map |
| Visibility | All people / all neighbors equal — shared map, no privileged roles |
| Location | **Mandatory** to submit |
| AR revisit / clear-confirm | Stretch goal, not v1 |
| Platform | Native iOS (SwiftUI), two tabs: Capture, Map. Web PoC is legacy. |
| Social | Votes, box fixes/adds, and voice notes on any report. No text comments/feed. |
| Identity | Anonymous friendly handles (e.g. `fire-onyx-support`). No accounts. |
| Editing | Anyone can change a label, move/resize a box, or add a box. A fix is a new box; the original stays. |
| Rejected suggestions | Still posted, carrying the poster’s no vote. |
| Confirmed label | **2 yes votes** |
| Voice notes | Max **30 seconds** |
| Voice / tone | Neighborly and a little playful |
| Backend | Deferred (post-critique). Scaffold stores everything on-device. |

## 17. Remaining open questions

1. Age / consent / sensitive-content rules for damaged homes on a public map?
2. How hard should we celebrate submit (“it’s on the map”) in v1 exploration UI?
3. Map pin precision: exact GPS vs slight fuzz for homes?
4. YOLO: on-device Core ML is the direction (offline after storms). Taxonomy and training data under research — see `research/`. Does the class set stay at 4 debris classes or shift toward the SAR-style 5 (incl. people)?
5. Shared backend choice (CloudKit vs Supabase/Firebase) — after critique.
6. Moderation for voice notes and photos on a public map.

## 18. Near-term next steps

1. Phone-test the current PoC; note friction vs this v1 loop (especially mandatory location + map gap).
2. Choose minimal persistence + map stack for Phase 1.
3. Decide YOLO path for exploration (mock → API → on-device).
4. Short tone guide (empty state, no-location block, confirm, upload success → map, power-line caution).
5. Spike: upload with lat/lng → pin on a simple shared map.
