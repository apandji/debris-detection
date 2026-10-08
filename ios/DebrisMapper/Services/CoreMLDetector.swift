import CoreML
import UIKit
import Vision

/// Runs the bundled DebrisDetector.mlpackage (YOLO, 640×640 input, NMS baked in) through Vision.
struct CoreMLDetector: Detector {
    /// Default cutoff for a suggestion.
    static let confidenceThreshold = 0.25
    /// Downed lines get a lower bar: a miss is the safety risk, and people confirm every box anyway.
    static let downedLineThreshold = 0.15
    static let iouThreshold = 0.7

    let modelVersion: String?
    private let model: VNCoreMLModel

    /// nil when the model isn't in the app bundle.
    init?() {
        guard let url = Bundle.main.url(forResource: "DebrisDetector", withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url),
              let vnModel = try? VNCoreMLModel(for: mlModel) else { return nil }
        // The NMS stage takes its thresholds as inputs; ask for the lowest one and filter per class below.
        vnModel.featureProvider = try? MLDictionaryFeatureProvider(dictionary: [
            "iouThreshold": Self.iouThreshold,
            "confidenceThreshold": min(Self.confidenceThreshold, Self.downedLineThreshold),
        ])
        let metadata = mlModel.modelDescription.metadata
        let version = metadata[.versionString] as? String
        model = vnModel
        modelVersion = (version?.isEmpty == false) ? version : nil
    }

    func detect(in image: UIImage) async -> [Detection] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let version = modelVersion
        let model = model
        return await Task.detached(priority: .userInitiated) {
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            guard (try? handler.perform([request])) != nil,
                  let results = request.results as? [VNRecognizedObjectObservation] else { return [] }
            return results.compactMap { Self.detection(from: $0, modelVersion: version) }
        }.value
    }

    private static func detection(from observation: VNRecognizedObjectObservation, modelVersion: String?) -> Detection? {
        // Ultralytics pads the NMS stage to 80 labels ("5"…"79"); those always score 0.
        // Labels are sorted by confidence, so the top one is the real class.
        guard let top = observation.labels.first,
              let label = DebrisClass(modelName: top.identifier) else { return nil }
        // Vision normalizes label confidences to sum to 1 (so the top one reads ~0.99),
        // and puts the row's raw total on the observation. Their product is the model's class score.
        let confidence = Double(observation.confidence * top.confidence)
        let threshold = label == .downedLineOrPole ? downedLineThreshold : confidenceThreshold
        guard confidence >= threshold else { return nil }
        // Vision boxes are normalized with a bottom-left origin; ours are top-left.
        let r = observation.boundingBox
        return Detection(
            label: label,
            box: BoundingBox(x: r.minX, y: 1 - r.maxY, w: r.width, h: r.height),
            confidence: confidence,
            modelVersion: modelVersion
        )
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
