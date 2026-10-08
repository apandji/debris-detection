# Faculty meeting notes (2026-10-02)

Ideas from a faculty meeting, clarified with Andrew afterwards. Nothing here is built yet.
For the orchestrator: fold the decisions into `PRD.md` and the open questions into `AGENTS.md`.

## Ideas

1. **LLM enrichment of new photos.** Send each new submission to a general-purpose multimodal LLM with a prompt like
   "Examine the attached image. Does it contain debris (yes/no)? Describe the debris and say whether it may be toxic."
   Use the **Gemini API** with structured output so it returns JSON in a fixed schema.
2. **City triage signals.** Besides toxicity, have the LLM rate **urgency** and **obstruction** so the city can clear the worst debris first.
3. **Volume estimate.** Turn a debris photo into a 3D model with **Meshy.ai** or **TRELLIS** (image-to-3D) and estimate its volume for cleanup planning.

## Decisions (Andrew, 2026-10-02)

- **YOLO stays.** The on-device Core ML model is still the detector: it draws the boxes and works offline. The `DebrisDetector.mlpackage` contract doesn't change.
- **The LLM is an add-on, not a replacement.** It runs on new submissions to add a description, toxicity, urgency, and obstruction. Like YOLO, its output is a suggestion, never ground truth.
- **Volume is a real feature:** a rough cleanup estimate (e.g. cubic yards per pile) so crews and the city can plan hauling. It's not just a critique mockup.
- **Toxicity shown to users: undecided** (see open questions).

## Draft JSON schema (starting point, not final)

```json
{
  "has_debris": true,
  "description": "Large oak uprooted across the sidewalk, branches touching a power line.",
  "debris_classes": ["fallen_tree", "downed_line_or_pole"],
  "toxicity": {
    "level": "none | possible | likely",
    "concerns": ["electrical", "asbestos_era_materials", "treated_wood", "chemicals", "fuel", "mold"],
    "reason": "string"
  },
  "obstruction": {
    "blocks": "none | sidewalk | driveway | one_lane | road",
    "reason": "string"
  },
  "urgency": "low | medium | high",
  "urgency_reason": "string",
  "confidence": 0.0
}
```

`debris_classes` reuses the model's five names, so the LLM and YOLO can be compared.

## How it fits the current plan

| Step | Where it runs | Needs network | Status |
|---|---|---|---|
| YOLO boxes | on device (Core ML) | no | training in progress |
| LLM enrichment (Gemini, JSON) | cloud, via our server | yes | idea |
| 3D volume (Meshy / TRELLIS) | cloud or GPU server | yes | idea |
| Neighbor votes | app | no (local for now) | built |

## Conflicts with current decisions

- **Needs a backend.** A Gemini or Meshy API key can't ship inside an open-source app, so calls must go through a server we run. `AGENTS.md` defers any backend until after the critique.
- **Photos leave the device.** Sending photos to Google or Meshy raises privacy questions (faces, house numbers, license plates) and needs clear wording in the app.
- **Offline after storms.** Enrichment and volume must queue until the phone is back online. YOLO keeps working offline.
- **Toxicity and safety.** An LLM can't confirm a hazard (e.g. asbestos), and must never imply something is safe. If it's shown, it needs careful "may contain" wording plus the standard safety line.

## Open questions

1. **Toxicity in the app:** show it to users, keep it for the city only, or keep it internal for now?
2. **Who is "the city"?** There's no city-facing view. Is it an export, a dashboard, or a 311 hand-off?
3. **Can neighbors vote on LLM fields** (urgency, obstruction, toxicity) the way they vote on boxes?
4. **Volume scale.** A single photo has no scale, so the volume could be off by a lot. Options: a reference object, iPhone LiDAR, several photos, or rough size buckets instead of numbers. Accuracy needs testing against measured piles.
5. **Meshy vs TRELLIS.** Meshy is a paid cloud API. TRELLIS is open source but needs a GPU server. Choose after a quick test on our photos.
6. **Cost and rate limits** for Gemini and Meshy per photo at storm scale.
7. **Training data.** Can LLM descriptions or classes pre-screen pool photos (like Grounding DINO)? Rule: never train on them unreviewed.
