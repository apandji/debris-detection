import AVFoundation
import UIKit
import Observation

/// Thin wrapper around AVCaptureSession for a full-screen preview and one shutter.
@Observable
final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate {
    enum State { case idle, running, denied, unavailable }

    private(set) var state: State = .idle
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    @ObservationIgnored private var isConfigured = false
    @ObservationIgnored private var onCapture: ((UIImage) -> Void)?

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.configureAndRun() } else { self.state = .denied }
                }
            }
        default:
            state = .denied
        }
    }

    func stop() {
        queue.async { self.session.stopRunning() }
    }

    func capture(_ completion: @escaping (UIImage) -> Void) {
        guard state == .running else { return }
        onCapture = completion
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    private func configureAndRun() {
        queue.async {
            if !self.isConfigured {
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input),
                      self.session.canAddOutput(self.output) else {
                    // e.g. the Simulator — Capture falls back to the photo library.
                    DispatchQueue.main.async { self.state = .unavailable }
                    return
                }
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                self.session.addInput(input)
                self.session.addOutput(self.output)
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            self.session.startRunning()
            DispatchQueue.main.async { self.state = .running }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async {
            self.onCapture?(image)
            self.onCapture = nil
        }
    }
}
