import Foundation
import UIKit
import CoreLocation
import Observation

/// Anonymous, device-local identity. No accounts: everyone gets a friendly
/// three-word handle like "fire-onyx-support", generated once per device.
enum CurrentUser {
    static let id: String = stored("currentUserID") { UUID().uuidString }
    static let name: String = stored("currentUserName") { FriendlyName.random() }

    private static func stored(_ key: String, make: () -> String) -> String {
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let new = make()
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}

enum FriendlyName {
    private static let first = ["fire", "maple", "river", "storm", "cedar", "lucky", "sunny", "brave", "quiet", "clover", "copper", "misty"]
    private static let second = ["onyx", "otter", "falcon", "pebble", "willow", "badger", "comet", "fern", "heron", "acorn", "lantern", "meadow"]
    private static let third = ["support", "helper", "scout", "porch", "patrol", "neighbor", "crew", "lookout", "sweep", "watch", "relay", "tide"]

    static func random() -> String {
        [first, second, third].map { $0.randomElement()! }.joined(separator: "-")
    }
}

/// Single source of truth for reports.
///
/// MOCK BACKEND: everything lives on this device (JSON + files in Documents).
/// "Other neighbors" are seeded fakes. When a real shared backend is chosen,
/// replace the bodies of `load`, `save`, and the mutators — keep the API.
@Observable
final class ReportStore {
    private(set) var reports: [Report] = []

    private let fm = FileManager.default
    private var docs: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    private var dbURL: URL { docs.appending(path: "reports.json") }
    var photosDir: URL { docs.appending(path: "photos", directoryHint: .isDirectory) }
    var voiceDir: URL { docs.appending(path: "voice", directoryHint: .isDirectory) }

    init() {
        try? fm.createDirectory(at: photosDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: voiceDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: Queries

    func report(id: Report.ID) -> Report? {
        reports.first { $0.id == id }
    }

    func image(for report: Report) -> UIImage? {
        guard let name = report.imageFileName else { return nil }
        return UIImage(contentsOfFile: photosDir.appending(path: name).path)
    }

    func voiceURL(for note: VoiceNote) -> URL {
        voiceDir.appending(path: note.fileName)
    }

    // MARK: Mutations

    /// Posts a new report. Only the poster's explicit votes are attached;
    /// suggestions they skipped stay unvoted (not ground truth).
    func post(image: UIImage, location: CLLocation, detections: [Detection]) {
        let id = UUID()
        let fileName = "\(id.uuidString).jpg"
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: photosDir.appending(path: fileName))
        }
        let report = Report(
            id: id,
            authorID: CurrentUser.id,
            authorName: CurrentUser.name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            imageFileName: fileName,
            detections: detections
        )
        reports.insert(report, at: 0)
        save()
    }

    /// A neighbor corrects someone else's box (new label and/or position).
    /// The original stays with its votes; the correction is a new box with the
    /// editor's yes, and the editor's vote on the original becomes no.
    func revise(reportID: Report.ID, detectionID: Detection.ID, label: DebrisClass, box: BoundingBox) {
        guard let r = reports.firstIndex(where: { $0.id == reportID }),
              let d = reports[r].detections.firstIndex(where: { $0.id == detectionID }) else { return }
        reports[r].detections[d].votes[CurrentUser.id] = false
        reports[r].detections.append(Detection(
            label: label,
            box: box,
            source: .person,
            revisionOf: detectionID,
            votes: [CurrentUser.id: true]
        ))
        save()
    }

    /// A neighbor draws a box the model missed. Counts as their yes.
    func addDetection(reportID: Report.ID, label: DebrisClass, box: BoundingBox) {
        guard let r = reports.firstIndex(where: { $0.id == reportID }) else { return }
        reports[r].detections.append(Detection(
            label: label,
            box: box,
            source: .person,
            votes: [CurrentUser.id: true]
        ))
        save()
    }

    /// Sets, changes, or (passing nil) clears the current user's vote.
    func vote(_ value: Bool?, reportID: Report.ID, detectionID: Detection.ID) {
        guard let r = reports.firstIndex(where: { $0.id == reportID }),
              let d = reports[r].detections.firstIndex(where: { $0.id == detectionID }) else { return }
        reports[r].detections[d].votes[CurrentUser.id] = value
        save()
    }

    func addVoiceNote(_ note: VoiceNote, to reportID: Report.ID) {
        guard let r = reports.firstIndex(where: { $0.id == reportID }) else { return }
        reports[r].voiceNotes.append(note)
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: dbURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        reports = (try? decoder.decode([Report].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(reports) {
            try? data.write(to: dbURL, options: .atomic)
        }
    }

    // MARK: Demo seed

    /// Scatters a few fake neighbor reports around the first location fix
    /// so the map isn't empty wherever the demo happens. Runs once.
    func seedIfNeeded(around center: CLLocationCoordinate2D) {
        let key = "didSeedDemoReports"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let neighbors = (0..<5).map { _ in FriendlyName.random() }
        let seeds: [(DebrisClass, Double, Double)] = [
            (.fallenTree, 0.0021, -0.0014),
            (.downedPowerLine, -0.0016, 0.0025),
            (.rubblePile, 0.0009, 0.0031),
            (.damagedBuilding, -0.0028, -0.0019),
            (.fallenTree, 0.0034, 0.0007),
        ]
        for (i, seed) in seeds.enumerated() {
            var votes: [String: Bool] = [:]
            for n in 0..<Int.random(in: 1...6) { votes["seed-\(i)-\(n)"] = Double.random(in: 0...1) < 0.8 }
            let detection = Detection(
                label: seed.0,
                box: BoundingBox(x: 0.2, y: 0.25, w: 0.55, h: 0.45),
                confidence: Double.random(in: 0.55...0.93),
                votes: votes
            )
            reports.append(Report(
                createdAt: Date().addingTimeInterval(-Double(i + 1) * 2700),
                authorID: "seed-\(i)",
                authorName: neighbors[i],
                latitude: center.latitude + seed.1,
                longitude: center.longitude + seed.2,
                imageFileName: nil,
                detections: [detection]
            ))
        }
        save()
    }
}
