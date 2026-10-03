import SwiftUI
import CoreLocation

/// After the shutter: mock YOLO runs, the poster confirms or rejects each suggestion, then posts.
struct ReviewView: View {
    let photo: PendingPhoto
    var onPosted: (Report.ID) -> Void

    @Environment(ReportStore.self) private var store
    @Environment(LocationManager.self) private var location
    @Environment(\.dismiss) private var dismiss

    @State private var detections: [Detection] = []
    @State private var isDetecting = true
    @State private var isEditing = false

    /// Capture-time (or EXIF) location first; live GPS as fallback.
    private var postLocation: CLLocation? { photo.location ?? location.location }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DetectionPhoto(image: photo.image, detections: detections) { d in
                        switch d.vote(of: CurrentUser.id) {
                        case true?: .confirmed
                        case false?: .rejected
                        case nil: .suggested
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    if isDetecting {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Squinting at your photo…").foregroundStyle(.secondary)
                        }
                    } else if detections.isEmpty {
                        Text("Nothing jumped out at us. Spot something? Tap Edit and add a box.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($detections) { $d in
                            DetectionRow(detection: d) {
                                VoteButtons(vote: d.vote(of: CurrentUser.id)) { d.votes[CurrentUser.id] = $0 }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("What We Spotted")
                        Spacer()
                        if !isDetecting {
                            Button("Edit") { isEditing = true }
                                .font(.subheadline)
                                .textCase(nil)
                        }
                    }
                } footer: {
                    if !isDetecting && !detections.isEmpty {
                        Text("These are our best guesses. Tap ✓ if we got it right, ✕ if not, or Edit to fix a label or box. Neighbors get a say once it's posted.")
                    }
                }

                if detections.contains(where: { $0.label == .downedPowerLine }) {
                    PowerLineWarning()
                }

                Section {
                    LabeledContent {
                        if let loc = postLocation {
                            Text(loc.coordinate.shortDescription).monospacedDigit()
                        } else if location.isDenied {
                            Text("Location Off").foregroundStyle(.red)
                        } else {
                            ProgressView()
                        }
                    } label: {
                        Label("Location", systemImage: "location.fill")
                    }
                } footer: {
                    Text("Heads up: posts are public. Neighbors will see this photo, where it was taken, and your handle, \(CurrentUser.name).")
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retake") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post", action: post)
                        .bold()
                        .disabled(isDetecting || postLocation == nil)
                }
            }
            .sheet(isPresented: $isEditing) {
                BoxEditorView(
                    image: photo.image,
                    detections: detections,
                    canDelete: { _ in true },
                    onDone: applyDraftEdits
                )
            }
            .task {
                detections = await MockDetector.detect(in: photo.image)
                isDetecting = false
            }
        }
    }

    /// The draft is the poster's alone, so edits apply in place. A box they
    /// drew or corrected counts as their yes, same as a neighbor's fix.
    private func applyDraftEdits(_ edited: [Detection]) {
        let before = Dictionary(uniqueKeysWithValues: detections.map { ($0.id, $0) })
        detections = edited.map { d in
            var d = d
            if let old = before[d.id] {
                guard old.label != d.label || old.box != d.box else { return d }
                d.source = .person
                d.confidence = nil
            }
            d.votes[CurrentUser.id] = true
            return d
        }
    }

    private func post() {
        guard let loc = postLocation else { return }
        store.post(image: photo.image, location: loc, detections: detections)
        if let id = store.reports.first?.id { onPosted(id) }
    }
}

/// Class icon, name, where the box came from, plus trailing controls.
struct DetectionRow<Trailing: View>: View {
    let detection: Detection
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: detection.label.symbol)
                .foregroundStyle(detection.label.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(detection.label.title)
                    if detection.isConfirmed {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Confirmed")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        if detection.revisionOf != nil { return "A neighbor's fix" }
        switch detection.source {
        case .person: return "Added by hand"
        case .model: return "Our guess · \(Int((detection.confidence ?? 0) * 100))% sure"
        }
    }
}

/// Safety note whenever a downed power line is in play (PRD §14).
struct PowerLineWarning: View {
    var body: some View {
        Section {
            Label {
                Text("Stay at least 35 feet back from downed lines (assume they're live) and call your utility or 911.")
                    .font(.subheadline)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
        }
    }
}

extension CLLocationCoordinate2D {
    var shortDescription: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}
