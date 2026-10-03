import AVFoundation
import Observation

/// Records one voice note at a time to an .m4a file, capped at `maxDuration`.
@Observable
final class VoiceRecorder {
    static let maxDuration: TimeInterval = 30

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var fileURL: URL?
    @ObservationIgnored private var onFinish: ((fileName: String, duration: TimeInterval)?) -> Void = { _ in }

    /// Starts recording. `onFinish` runs once, on `stop()` or when the cap is hit,
    /// with nil if the clip was too short to keep.
    /// Returns false if mic permission is denied or recording can't start.
    func start(in directory: URL, onFinish: @escaping ((fileName: String, duration: TimeInterval)?) -> Void) async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let url = directory.appending(path: "\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            guard recorder.record() else { return false }
            self.recorder = recorder
            self.onFinish = onFinish
            fileURL = url
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let recorder = self.recorder else { return }
                self.elapsed = min(recorder.currentTime, Self.maxDuration)
                if recorder.currentTime >= Self.maxDuration { self.stop() }
            }
            return true
        } catch {
            return false
        }
    }

    /// Stops recording and reports the result through `onFinish`.
    func stop() {
        guard isRecording else { return }
        let duration = min(recorder?.currentTime ?? elapsed, Self.maxDuration)
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        recorder = nil
        isRecording = false
        let finish = onFinish
        onFinish = { _ in }
        guard let url = fileURL else { return finish(nil) }
        fileURL = nil
        if duration < 0.5 {
            try? FileManager.default.removeItem(at: url)
            finish(nil)
        } else {
            finish((url.lastPathComponent, duration))
        }
    }
}

/// Plays one voice note at a time.
@Observable
final class VoicePlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var playingID: VoiceNote.ID?
    @ObservationIgnored private var player: AVAudioPlayer?

    func toggle(_ note: VoiceNote, url: URL) {
        if playingID == note.id {
            stop()
            return
        }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.delegate = self
        player.play()
        self.player = player
        playingID = note.id
    }

    func stop() {
        player?.stop()
        player = nil
        playingID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playingID = nil
    }
}
