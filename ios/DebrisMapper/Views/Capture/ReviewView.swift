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
                            Text("Looking for debris…").foregroundStyle(.secondary)
                        }
                    } else if detections.isEmpty {
                        Text("No debris found.").foregroundStyle(.secondary)
                    } else {
                        ForEach($detections) { $d in
                            DetectionRow(detection: d) {
                                VoteButtons(vote: d.vote(of: CurrentUser.id)) { d.votes[CurrentUser.id] = $0 }
                            }
                        }
                    }
                } header: {
                    Text("Suggestions")
                } footer: {
                    if !isDetecting && !detections.isEmpty {
                        Text("Suggestions are guesses. Confirm what you see; neighbors can weigh in after you post.")
                    }
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
                    Text("Posts are public. Your photo and location appear on the shared map.")
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
            .task {
                detections = await MockDetector.detect(in: photo.image)
                isDetecting = false
            }
        }
    }

    private func post() {
        guard let loc = postLocation else { return }
        store.post(image: photo.image, location: loc, detections: detections)
        if let id = store.reports.first?.id { onPosted(id) }
    }
}

/// Class icon, name, model confidence, plus trailing controls.
struct DetectionRow<Trailing: View>: View {
    let detection: Detection
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: detection.label.symbol)
                .foregroundStyle(detection.label.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(detection.label.title)
                Text("Suggested · \(Int(detection.confidence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }
}

extension CLLocationCoordinate2D {
    var shortDescription: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}
