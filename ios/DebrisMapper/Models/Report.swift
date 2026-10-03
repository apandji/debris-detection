import Foundation
import CoreLocation

/// Debris classes for the PoC. Keep in sync with the web PoC and PRD §9.
enum DebrisClass: String, Codable, CaseIterable, Identifiable {
    case fallenTree
    case damagedBuilding
    case rubblePile
    case downedPowerLine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fallenTree: "Fallen tree"
        case .damagedBuilding: "Damaged building"
        case .rubblePile: "Rubble pile"
        case .downedPowerLine: "Downed power line"
        }
    }

    var symbol: String {
        switch self {
        case .fallenTree: "tree.fill"
        case .damagedBuilding: "house.fill"
        case .rubblePile: "square.stack.3d.down.right.fill"
        case .downedPowerLine: "bolt.fill"
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
