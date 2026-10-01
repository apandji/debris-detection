import SwiftUI

/// One report, as any neighbor sees it: photo, community votes on each detection, voice notes.
struct ReportDetailView: View {
    let reportID: Report.ID

    @Environment(ReportStore.self) private var store
    @State private var recorder = VoiceRecorder()
    @State private var player = VoicePlayer()
    @State private var micDenied = false

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
            if recorder.isRecording { _ = recorder.stop() }
        }
    }

    private func content(_ report: Report) -> some View {
        List {
            Section {
                DetectionPhoto(image: store.image(for: report), detections: report.detections) { d in
                    if d.confirmCount > d.rejectCount { return .confirmed }
                    if d.rejectCount > d.confirmCount { return .rejected }
                    return .suggested
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Is this right?") {
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
            }

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
                }
            }
        }
        .navigationTitle(report.primaryClass?.title ?? "Report")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text("\(report.authorName) · \(report.createdAt.formatted(.relative(presentation: .named)))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private func recordButton(_ report: Report) -> some View {
        if recorder.isRecording {
            Button {
                if let result = recorder.stop() {
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
            } label: {
                HStack {
                    Image(systemName: "stop.circle.fill").foregroundStyle(.red)
                    Text("Stop Recording")
                    Spacer()
                    Text(Duration.seconds(recorder.elapsed).formatted(.time(pattern: .minuteSecond)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                player.stop()
                Task { micDenied = !(await recorder.start(in: store.voiceDir)) }
            } label: {
                Label("Add Voice Note", systemImage: "mic.fill")
            }
        }
    }
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.authorName).foregroundStyle(.primary)
                    Text(note.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Duration.seconds(note.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}
