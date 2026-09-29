# PRD outline — Neighborhood storm debris tagging

Status: draft outline  
Product working name: TBD  
Related PoC: `index.html` human-in-the-loop debris labeling

---

## 1. One-liner

A lightweight phone app where neighbors photograph and tag storm debris — turning “it just sits in the camera roll” into a small, shared act of noticing after bad weather.

## 2. Inspiration & tone

- Inspired by people walking around after tornadoes / storms, taking pictures of fallen trees, damaged roofs, rubble, downed lines — and those photos never leaving the phone.
- The product should bring **levity and joy**, not disaster-tourism or heavy civic bureaucracy.
- Feel: neighborly, slightly playful, clear, quick. Not a government portal. Not a grim ops dashboard.
- Humor is welcome in copy and UI personality; never at the expense of people who were hurt or lost homes.

## 3. Problem

After a storm, neighbors already document debris with their phones. That effort is wasted:

1. Photos stay private in camera rolls.
2. There’s no easy way to label *what* is in the photo.
3. There’s no lightweight shared picture of “what’s out there on our block.”

Separately, better debris detection models need real human-confirmed labels — but collection has to feel worth doing for ordinary people, not only for ML engineers.

## 4. Goals

### Product goals
- Make “snap → tag → share/send” take under a minute on a phone.
- Give neighbors a sense that their photos *go somewhere useful* (community awareness and/or model improvement — TBD which is primary for v1).
- Keep the experience emotionally light enough that people actually open the app after a storm.

### Learning goals (PoC → product)
- Validate that neighbors will confirm/correct debris labels in the field.
- Learn which classes people can tag confidently.
- Decide how much geospatial context is required vs optional.

## 5. Non-goals (for now)

- Full GIS / map product, tile layers, routing.
- Official emergency-management tooling or 911 integration.
- User accounts, social feed, comments, or neighborhood chat (unless later required).
- Real-time multiplayer labeling queues.
- Polished design system / brand campaign before the core loop works.
- Large-scale YOLO training pipeline before we can store confirmed labels.

## 6. Users

### Primary
- **Neighbors / residents** after a storm: walk the block, take a photo, tag what they see, move on.

### Secondary (later)
- Local mutual-aid / HOA / block organizers who want a simple picture of reported debris.
- Model trainers who use confirmed tags as ground truth.

Assume: one hand, outdoor light, spotty connectivity, emotional fatigue after severe weather. UI must be thumb-friendly and forgiving.

## 7. Core experience loop

1. Open app (HTTPS on phone).
2. Take photo (preferred) or upload from camera roll.
3. See suggested debris boxes (mock YOLO today → real model later).
4. Confirm, fix, add, or delete tags — **only confirmed tags count**.
5. Optionally attach / show location (EXIF when present; otherwise “location not attached”).
6. Submit. Get a clear success moment that feels like a small win, not a form receipt.
7. Done — back to walking the block.

The emotional beat after submit should reinforce usefulness and lightness (“tagged,” “sent,” “counted”) rather than clinical ML language.

## 8. Debris classes (starting set)

Keep the current PoC set until phone testing says otherwise:

| Class | Notes |
|---|---|
| Fallen tree | Common, easy for neighbors to recognize |
| Damaged building | Sensitive — copy should stay respectful |
| Rubble pile | Broad; may need clearer examples |
| Downed power line | Safety-sensitive — never encourage approaching lines |

Open: merge/split classes? Add flooded street, debris on road, etc.?

## 9. Product principles

1. **Neighbor first, model second.** Training data is a byproduct of a useful human moment.
2. **Confirmed only.** Unconfirmed suggestions are never ground truth.
3. **Joy without denial.** Light tone; still honest that storms suck.
4. **Phone-native.** Camera, big taps, short copy, works in sunlight.
5. **Geo is required eventually, not a map product yet.** Capture lat/lng when we can; don’t block tagging if EXIF is missing (decision TBD).
6. **Don’t overbuild.** Vanilla, fast, shippable slices beat architecture theater.

## 10. Functional requirements (outline)

### Must have (v1)
- [ ] Camera capture + upload
- [ ] Bounding-box review: confirm / edit label / move / resize / delete / add
- [ ] Clear confirmed vs suggestion state
- [ ] Submit with success / failure feedback
- [ ] Persist confirmed annotations somewhere real (beyond mock ack)
- [ ] Location: EXIF GPS when available; honest empty state when not
- [ ] Mobile-first layout; works on personal phone over HTTPS

### Nice to have
- [ ] Lightweight “you tagged N things” personal streak / neighborhood total (joy metric, not gamification treadmill)
- [ ] Before/after or “walk complete” moment
- [ ] Offline queue + sync when back online
- [ ] Simple public or shared neighborhood summary (privacy TBD)

### Explicitly later
- [ ] Real YOLO / ONNX inference in the loop
- [ ] Training export + model registry
- [ ] Auth / multi-neighborhood tenancy
- [ ] Map view of reports

## 11. Geospatial (hard requirement, still scoped)

**Need:** debris reports should be place-aware enough to be useful locally.  
**Not building yet:** interactive map product.

### Open decisions
- Is location required to submit, or optional with a nudge?
- Is EXIF enough for v1, or do we need a one-tap “use my current location”?
- Who can see lat/lng — only the submitter, organizers, or a public pin (blurred)?

## 12. Success metrics

### Experience
- Time from open → successful submit (target: &lt; 60s for a simple photo).
- % of sessions that confirm ≥1 box.
- Qualitative: “Would you open this again after the next storm?”

### Data quality
- Confirmed boxes per photo.
- Correction rate vs model suggestions (once real model exists).
- Class confusion (which labels get changed most).

### Joy / levity (soft)
- People share the app or talk about tagging as something they *wanted* to do.
- Copy/UI feedback that lands as warm, not corny (validate in phone tests).

## 13. Risks & constraints

- **Tone risk:** too cute after real damage → feels tone-deaf; too serious → nobody opens it.
- **Safety:** downed power lines / unstable structures — app must never encourage unsafe approach.
- **Privacy:** house damage photos + GPS are sensitive.
- **Connectivity:** post-storm networks are bad; design for flaky submit.
- **Cold start:** mock detections today; without persistence, neighbor effort is discarded.

## 14. Phased roadmap (suggested)

### Phase 0 — PoC (mostly done)
- Mock YOLO labeling UI, EXIF GPS placeholder, Vercel phone HTTPS path.

### Phase 1 — Neighbor-ready loop
- Permanent deploy, phone UX polish, real persistence for confirmed tags, tone pass on copy/UI for levity.

### Phase 2 — Place & trust
- Resolve geo rules; optional current-location fallback; privacy defaults; safety copy for power lines.

### Phase 3 — Real detections
- Export confirmed labels → train small YOLO → replace mocks → measure whether tagging gets faster/easier.

### Phase 4 — Shared neighborhood picture
- Lightweight summary for a block/area (still not a full map product unless PRD expands).

## 15. Open questions

1. Working name / brand voice (playful name vs plain descriptive)?
2. Is v1 primarily **community documentation** or **model-label collection** — or both equally?
3. Who sees submitted photos — private, block-only, or broader?
4. Must location be present to count as a “real” report?
5. Any age / consent / sensitive-content rules for damaged homes?
6. Do we want a “thank you / tagged” celebration moment after submit, and how big should it be?

## 16. Near-term next steps

1. Fill gaps in this outline (especially §§11, 12, 15).
2. Phone-test the current PoC; note friction and tone misses.
3. Decide persistence target for confirmed annotations (minimal store).
4. Write a short tone guide (3–5 example strings: empty state, confirm, submit success, no GPS, power-line caution).
5. Only then: UI refinement pass and first real training dataset plan.
