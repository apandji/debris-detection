import UIKit

/// Stand-in for a YOLO model. Returns 1–3 random suggestions after a short delay
/// so the UI has a realistic "detecting…" beat. Swap for Core ML later; keep the signature.
enum MockDetector {
    static func detect(in image: UIImage) async -> [Detection] {
        try? await Task.sleep(for: .milliseconds(900))
        let count = Int.random(in: 1...3)
        return (0..<count).map { _ in
            let w = Double.random(in: 0.25...0.5)
            let h = Double.random(in: 0.2...0.45)
            return Detection(
                label: DebrisClass.allCases.randomElement()!,
                box: BoundingBox(
                    x: Double.random(in: 0.05...(0.95 - w)),
                    y: Double.random(in: 0.08...(0.92 - h)),
                    w: w,
                    h: h
                ),
                confidence: Double.random(in: 0.45...0.95)
            )
        }
    }
}
