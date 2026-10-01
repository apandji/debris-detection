import AVFoundation
import Observation

/// Records one voice note at a time to an .m4a file.
@Observable
final class VoiceRecorder {
    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var fileURL: URL?

    /// Returns false if mic permission is denied or recording can't start.
    func start(in directory: URL) async -> Bool {
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
            fileURL = url
            elapsed = 0
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                self?.elapsed = self?.recorder?.currentTime ?? 0
            }
            return true
        } catch {
            return false
        }
    }

    /// Stops and returns (file name, duration), or nil if nothing usable was recorded.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        timer?.invalidate()
        timer = nil
        recorder = nil
        isRecording = false
        defer { fileURL = nil }
        guard let url = fileURL, duration >= 0.5 else {
            if let url = fileURL { try? FileManager.default.removeItem(at: url) }
            return nil
        }
        return (url.lastPathComponent, duration)
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
