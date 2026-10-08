import SwiftUI

/// One report, as any neighbor sees it: photo, community votes on each detection, voice notes.
struct ReportDetailView: View {
    let reportID: Report.ID

    @Environment(ReportStore.self) private var store
    @State private var recorder = VoiceRecorder()
    @State private var player = VoicePlayer()
    @State private var micDenied = false
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            if let report = store.report(id: reportID) {
                content(report)
            } else {
                ContentUnavailableView("Report Not Found", systemImage: "questionmark.circle")
            }
        }
        .onDisappear {
            player.stop()
            recorder.stop()
        }
    }

    private func content(_ report: Report) -> some View {
        List {
            Section {
                DetectionPhoto(image: store.image(for: report), detections: report.detections) { d in
                    if d.isConfirmed { return .confirmed }
                    if d.rejectCount > d.confirmCount { return .rejected }
                    return .suggested
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(report.detections) { d in
                    DetectionRow(detection: d) {
                        VStack(alignment: .trailing, spacing: 6) {
                            VoteButtons(vote: d.vote(of: CurrentUser.id)) {
                                store.vote($0, reportID: report.id, detectionID: d.id)
                            }
                            Text("\(d.confirmCount) yes · \(d.rejectCount) no")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Did We Get It Right?")
                    Spacer()
                    Button("Edit Boxes") { isEditing = true }
                        .font(.subheadline)
                        .textCase(nil)
                }
            } footer: {
                Text("A box is confirmed once \(Detection.confirmThreshold) neighbors say yes. Wrong label or spot? Edit Boxes to suggest a fix.")
            }

            SafetyWarnings(labels: report.detections.map(\.label))

            Section {
                ForEach(report.voiceNotes) { note in
                    VoiceNoteRow(note: note, isPlaying: player.playingID == note.id) {
                        player.toggle(note, url: store.voiceURL(for: note))
                    }
                }
                recordButton(report)
            } header: {
                Text("Voice Notes")
            } footer: {
                if micDenied {
                    Text("Microphone access is off. Turn it on in Settings to leave a voice note.")
                } else {
                    Text("Up to \(Int(VoiceRecorder.maxDuration)) seconds. Tell neighbors what you saw, or that it's been cleared.")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            BoxEditorView(
                image: store.image(for: report),
                detections: report.detections,
                // Existing boxes stay (vote them down instead); only new ones can be removed.
                canDelete: { d in !report.detections.contains(where: { $0.id == d.id }) },
                onDone: { applyEdits($0, to: report) }
            )
        }
        .navigationTitle(report.primaryClass?.title ?? "Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Title + byline in the bar, so scrolled content never runs under the byline.
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(report.primaryClass?.title ?? "Report")
                        .font(.headline)
                    Text("\(displayName(report.authorID, report.authorName)) · \(report.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func recordButton(_ report: Report) -> some View {
        if recorder.isRecording {
            Button {
                recorder.stop()
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                    Text("Stop Recording")
                    Spacer()
                    Text("\(mmss(recorder.elapsed)) / \(mmss(VoiceRecorder.maxDuration))")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                player.stop()
                Task {
                    let started = await recorder.start(in: store.voiceDir) { result in
                        guard let result else { return }
                        store.addVoiceNote(
                            VoiceNote(
                                authorID: CurrentUser.id,
                                authorName: CurrentUser.name,
                                fileName: result.fileName,
                                duration: result.duration
                            ),
                            to: report.id
                        )
                    }
                    micDenied = !started
                }
            } label: {
                Label("Add Voice Note", systemImage: "mic.fill")
            }
        }
    }

    /// Diff the editor's result against the report: changed boxes become a
    /// neighbor's fix (the original stays), new boxes are added. Nothing is overwritten.
    private func applyEdits(_ edited: [Detection], to report: Report) {
        let originals = Dictionary(uniqueKeysWithValues: report.detections.map { ($0.id, $0) })
        for d in edited {
            if let old = originals[d.id] {
                if old.label != d.label || old.box != d.box {
                    store.revise(reportID: report.id, detectionID: d.id, label: d.label, box: d.box)
                }
            } else {
                store.addDetection(reportID: report.id, label: d.label, box: d.box)
            }
        }
    }
}

func mmss(_ t: TimeInterval) -> String {
    Duration.seconds(t).formatted(.time(pattern: .minuteSecond))
}

func displayName(_ id: String, _ name: String) -> String {
    id == CurrentUser.id ? "\(name) (you)" : name
}

struct VoiceNoteRow: View {
    let note: VoiceNote
    let isPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(note.authorID, note.authorName)).foregroundStyle(.primary)
                    Text(note.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(mmss(note.duration))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        // Plain, so only the play icon carries the tint; the row text stays primary/secondary.
        .buttonStyle(.plain)
    }
}
