import Foundation
import CoreLocation

/// Debris classes. Order and model names match the Core ML contract
/// (AGENTS.md): fallen_tree, damaged_building, rubble_debris, downed_line_or_pole, fire_smoke.
enum DebrisClass: String, Codable, CaseIterable, Identifiable {
    case fallenTree
    case damagedBuilding
    case rubbleDebris
    case downedLineOrPole
    case fireSmoke

    var id: String { rawValue }

    /// Label name in DebrisDetector.mlpackage.
    var modelName: String {
        switch self {
        case .fallenTree: "fallen_tree"
        case .damagedBuilding: "damaged_building"
        case .rubbleDebris: "rubble_debris"
        case .downedLineOrPole: "downed_line_or_pole"
        case .fireSmoke: "fire_smoke"
        }
    }

    init?(modelName: String) {
        guard let match = Self.allCases.first(where: { $0.modelName == modelName }) else { return nil }
        self = match
    }

    /// Reports saved before the 5-class model used the PoC names.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "rubblePile": self = .rubbleDebris
        case "downedPowerLine": self = .downedLineOrPole
        default:
            guard let value = Self(rawValue: raw) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown class \(raw)"))
            }
            self = value
        }
    }

    var title: String {
        switch self {
        case .fallenTree: "Fallen tree"
        case .damagedBuilding: "Damaged building"
        case .rubbleDebris: "Rubble or debris"
        case .downedLineOrPole: "Downed line or pole"
        case .fireSmoke: "Fire or smoke"
        }
    }

    var symbol: String {
        switch self {
        case .fallenTree: "tree.fill"
        case .damagedBuilding: "house.fill"
        case .rubbleDebris: "square.stack.3d.down.right.fill"
        case .downedLineOrPole: "bolt.fill"
        case .fireSmoke: "flame.fill"
        }
    }
}

/// Normalized box: 0–1, top-left origin.
struct BoundingBox: Codable, Hashable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double
}

/// One box on a photo plus every neighbor's vote on it.
/// A model suggestion is NOT ground truth. Only human votes count.
struct Detection: Identifiable, Codable, Hashable {
    enum Source: String, Codable { case model, person }

    /// Yes votes needed before a box counts as a confirmed training label.
    static let confirmThreshold = 2

    var id = UUID()
    var label: DebrisClass
    var box: BoundingBox
    var source: Source = .model
    /// Model confidence; nil for boxes people drew.
    var confidence: Double?
    /// Which model suggested this box (e.g. "v0"), so labels trace back to it. nil for boxes people drew.
    var modelVersion: String?
    /// Set when a neighbor corrected another box (label or position). The original stays.
    var revisionOf: UUID?
    /// userID → true (yes) / false (no)
    var votes: [String: Bool] = [:]

    var confirmCount: Int { votes.values.filter { $0 }.count }
    var rejectCount: Int { votes.values.filter { !$0 }.count }
    var isConfirmed: Bool { confirmCount >= Self.confirmThreshold }

    func vote(of userID: String) -> Bool? { votes[userID] }
}

struct VoiceNote: Identifiable, Codable, Hashable {
    var id = UUID()
    var authorID: String
    var authorName: String
    var fileName: String
    var duration: TimeInterval
    var createdAt = Date()
}

struct Report: Identifiable, Codable, Hashable {
    var id = UUID()
    var createdAt = Date()
    var authorID: String
    var authorName: String
    var latitude: Double
    var longitude: Double
    /// nil for seeded mock reports (detail view shows a placeholder).
    var imageFileName: String?
    var detections: [Detection]
    var voiceNotes: [VoiceNote] = []

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Label shown on the map pin: the detection with the most confirmations.
    var primaryClass: DebrisClass? {
        detections.max { $0.confirmCount < $1.confirmCount }?.label
    }
}
