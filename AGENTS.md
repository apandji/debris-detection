# AGENTS.md

Guidance for coding agents working on this repo.

## Purpose

Human-in-the-loop YOLO debris identification. A person reviews a photo, confirms or corrects detections, and those confirmed labels become new training input so the model improves.

Debris classes in the current PoC: fallen tree, damaged building, rubble pile, downed power line.

## Current state

- Vanilla `index.html` PoC only. No build step, no framework, no backend.
- YOLO detections are **mocked** in the page when an image loads. There is no real model.
- Resubmit `POST`s JSON to `/api/annotations`. That endpoint does not exist; a 4xx/5xx or network error is expected. The UI must still show a clear success or failure state.
- Geospatial is a **hard requirement** but is still being scoped with the user. Do not build a map product. The PoC only reads JPEG EXIF GPS when present and otherwise shows “location not attached”.

## Layout

- `index.html` — entire UI (markup, CSS, JS).
- `AGENTS.md` — this file.

Keep new work in the repo root unless asked to split files. Prefer editing `index.html` over adding a bundler or `src/` tree.

## Conventions

- Vanilla HTML/CSS/JS. Do **not** add React, Vue, Next, Tailwind, or a component library unless explicitly asked.
- No package.json / node toolchain unless asked.
- Bounding boxes are stored normalized (`x, y, w, h` in 0–1, top-left origin) plus pixel `xmin/ymin/xmax/ymax` on submit.
- Mock labels are suggestions. The operator can edit the label, move/resize/delete a box, or add a box.

## Annotations are ground truth

- Only **user-confirmed** boxes are training labels. Unconfirmed mock detections are not ground truth and must not be treated as such.
- A confirmed box is ground truth even if the original YOLO (mock) label was wrong — the user’s label wins.
- Do not silently overwrite user edits, re-run mock detections over confirmed boxes, or auto-confirm anything.
- The submit payload should send image metadata plus the confirmed annotation list only.

## What not to overbuild

- No real YOLO, ONNX, Python training loop, dataset exporter, or model registry.
- No real `/api/annotations` server, database, or auth unless asked.
- No map SDK, tile layer, or GIS stack. Keep GPS as a placeholder (EXIF lat/lng or a not-attached note).
- No extra docs, design system, or sample image assets unless needed for the task.
- Do not invent extra debris classes, user accounts, or multi-photo queues without being asked.

## How to run

Serve the repo root with any static server (needed so `fetch('/api/annotations')` is same-origin). Opening the file via `file://` is not the intended path.
