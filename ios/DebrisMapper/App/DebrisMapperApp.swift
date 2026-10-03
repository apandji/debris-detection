import SwiftUI

@main
struct DebrisMapperApp: App {
    @State private var store = ReportStore()
    @State private var location = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(location)
        }
    }
}

struct RootView: View {
    enum AppTab { case capture, map }

    @Environment(ReportStore.self) private var store
    @Environment(LocationManager.self) private var location

    @State private var tab: AppTab = .capture
    /// Set after posting so the Map tab flies to the new pin.
    @State private var focusedReportID: Report.ID?

    var body: some View {
        TabView(selection: $tab) {
            CaptureView { newID in
                focusedReportID = newID
                tab = .map
            }
            .tabItem { Label("Capture", systemImage: "camera") }
            .tag(AppTab.capture)

            ReportMapView(focusedReportID: $focusedReportID)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(AppTab.map)
        }
        .onAppear { location.start() }
        .onChange(of: location.location) { _, new in
            if let new { store.seedIfNeeded(around: new.coordinate) }
        }
    }
}
