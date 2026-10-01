# Model brief (from a Gemini brainstorm, 2026-10-01)

> Input for model research, saved as the user shared it. **Not a decision.** It differs from the app in two ways that still need a call:
> - **Taxonomy:** 5 SAR-style classes, including people (`bystander_survivor`), versus the app's 4 debris classes (fallen tree, damaged building, rubble pile, downed power line).
> - **Inference mode:** live video at 5–10 FPS, versus the app's current one photo per shutter press.
>
> Dataset research: `research/yolo-datasets.md`.

---

# Agent Context: Ground-Level Post-Tornado YOLO Model for iOS

## 🎯 Project Overview
This project involves building and deploying a custom **YOLO** (You Only Look Once) computer vision model tailored for **ground-level post-tornado situational awareness and search & rescue (SAR)**. The model will run entirely **offline** on a native **iOS smartphone app** to assist first responders and citizens navigating disaster zones.

---

## 🏗️ Model Architecture & Data Taxonomy
The model is optimized for a **ground-level view** (dashcams, smartphones, handheld footage) rather than aerial/satellite views. To prevent visual clutter on mobile screens, the taxonomy is condensed into **5 high-impact action categories**:

### Class Map:
* `0: bystander_survivor` — Stranded individuals, injured persons, or handwritten SOS signs.
* `1: wire_pole_hazard` — Downed power lines, low-hanging wires, and fallen utility poles.
* `2: structural_collapse` — Unstable facades, bowing walls, exposed rebar, and blocked entryways.
* `3: road_impassable` — Large debris fields rendering paths completely undrivable/impassable.
* `4: hazardous_leak` — Ruptured gas lines, crushed propane tanks, active fire, or smoke plumes.

### Training Requirements:
* **Base Architecture:** `YOLOv8n` or `YOLOv11n` (Nano variants) to fit mobile compute envelopes.
* **Augmentations Needed:** Heavy use of `Blur`, `MotionBlur`, `MixUp`, and `Mosaic` to handle camera shake and severe physical occlusion typical of disaster zones.

---

## 📱 iOS Target & Deployment Specifications
Because cell towers are frequently destroyed in tornadic events, the application **must perform edge-inference with zero internet connectivity**.

### Core Technical Stack:
* **Core Frameworks:** `AVFoundation` (Camera capture), `Vision` (Image scaling/handling), `CoreML` (Inference execution).
* **Export Pipeline:** Exported from PyTorch (`.pt`) via Ultralytics into a quantized Apple CoreML package (`.mlpackage`).
* **Hardware Acceleration:** Configuration targets `.cpuAndNeuralEngine` to exploit the Apple Neural Engine (ANE) for low-power, high-efficiency execution.

### Python Export Command:
```python
from ultralytics import YOLO

model = YOLO("best.pt")
model.export(format="coreml", quantize=8, imgsz=640)
```

### Native Swift Pipeline Template:
```swift
import CoreML
import Vision
import AVFoundation

func setupVisionModel() -> VNCoreMLRequest? {
    do {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        
        let coreMLModel = try Best(configuration: config).model
        let visionModel = try VNCoreMLModel(for: coreMLModel)
        
        return VNCoreMLRequest(model: visionModel) { request, error in
            guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
            for observation in results {
                let topResult = observation.labels.first
                // Bounding box coordinates and label extraction logic goes here
            }
        }
    } catch {
        return nil
    }
}
```

---

## 🔋 Mobile Constraints & Optimization Goals
1. **Thermal & Battery Management:** Inference must be throttled to **5–10 FPS** instead of running at the full 30 FPS camera capture rate to prevent the phone from overheating or dying rapidly in the field.
2. **Model Footprint:** Post-training 8-bit quantization (`INT8`) is mandatory to shrink the final package down to ~1.5MB for rapid installation and minimal RAM usage.
