import SwiftUI
import PhotosUI
import AVFoundation
import CoreLocation
import ImageIO

/// A captured or picked photo waiting for review.
struct PendingPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    /// Location at the moment of capture (or from EXIF for library photos).
    let location: CLLocation?
}

/// Tab 1: full-screen camera with one shutter button.
struct CaptureView: View {
    /// Called with the new report's ID after a successful post.
    var onPosted: (Report.ID) -> Void

    @Environment(LocationManager.self) private var location
    @State private var camera = CameraModel()
    @State private var pending: PendingPhoto?
    @State private var pickerItem: PhotosPickerItem?
    @State private var flash = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch camera.state {
            case .running, .idle:
                CameraPreview(session: camera.session)
                    .ignoresSafeArea(edges: .top)
            case .denied:
                unavailable(
                    title: "Camera Access Off",
                    message: "Turn on camera access in Settings, or choose a photo from your library."
                )
            case .unavailable:
                unavailable(
                    title: "No Camera",
                    message: "This device has no camera. Choose a photo from your library instead."
                )
            }

            if flash {
                Color.white.ignoresSafeArea().transition(.opacity)
            }

            VStack {
                LocationPill()
                    .padding(.top, 8)
                Spacer()
                controls
                    .padding(.bottom, 24)
            }
        }
        // Camera-app look: dark tab bar on this tab only.
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.black, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await loadPicked(item) }
        }
        .fullScreenCover(item: $pending) { photo in
            ReviewView(photo: photo) { newID in
                pending = nil
                onPosted(newID)
            }
        }
    }

    private var controls: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Choose from library")

            Spacer()

            Button(action: shoot) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 64, height: 64)
                }
            }
            .disabled(camera.state != .running)
            .opacity(camera.state == .running ? 1 : 0.4)
            .accessibilityLabel("Take photo")
            .sensoryFeedback(.impact, trigger: pending?.id)

            Spacer()

            // Balances the library button so the shutter stays centered.
            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.horizontal, 32)
    }

    private func unavailable(title: String, message: String) -> some View {
        ContentUnavailableView(title, systemImage: "camera", description: Text(message))
            .foregroundStyle(.white)
    }

    private func shoot() {
        let snapshot = location.location
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        camera.capture { image in
            withAnimation(.easeIn(duration: 0.2)) { flash = false }
            pending = PendingPhoto(image: image, location: snapshot)
        }
    }

    private func loadPicked(_ item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        // Prefer where the photo was taken; ReviewView falls back to device GPS.
        pending = PendingPhoto(image: image, location: EXIFLocation.read(from: data))
    }
}

/// "Located ±8 m" / "Locating…" / "Location Off" capsule.
struct LocationPill: View {
    @Environment(LocationManager.self) private var location

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .environment(\.colorScheme, .dark)
    }

    private var text: String {
        if location.isDenied { return "Location Off" }
        guard let loc = location.location else { return "Locating…" }
        return "Located ±\(Int(loc.horizontalAccuracy.rounded())) m"
    }

    private var symbol: String {
        if location.isDenied { return "location.slash" }
        return location.location == nil ? "location" : "location.fill"
    }
}

/// AVCaptureVideoPreviewLayer in SwiftUI.
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Reads GPS from photo metadata (library picks). Camera captures use device GPS.
enum EXIFLocation {
    static func read(from data: Data) -> CLLocation? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              var lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              var lon = gps[kCGImagePropertyGPSLongitude as String] as? Double else { return nil }
        if (gps[kCGImagePropertyGPSLatitudeRef as String] as? String) == "S" { lat = -lat }
        if (gps[kCGImagePropertyGPSLongitudeRef as String] as? String) == "W" { lon = -lon }
        return CLLocation(latitude: lat, longitude: lon)
    }
}
