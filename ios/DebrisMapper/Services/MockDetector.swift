import UIKit

/// Suggests debris boxes on a photo. Suggestions are never ground truth;
/// people vote on them (AGENTS.md).
protocol Detector {
    /// Shown in the UI and saved on each suggested box, e.g. "v0". nil for the mock.
    var modelVersion: String? { get }
    func detect(in image: UIImage) async -> [Detection]
}

enum Detectors {
    /// The bundled Core ML model when present, otherwise the mock.
    static let current: Detector = CoreMLDetector() ?? MockDetector()
}

/// Stand-in used when DebrisDetector.mlpackage isn't bundled (see ios/fetch-model.sh).
/// Returns 1–3 random suggestions after a short delay so the UI has a realistic "detecting…" beat.
struct MockDetector: Detector {
    let modelVersion: String? = nil

    func detect(in image: UIImage) async -> [Detection] {
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
