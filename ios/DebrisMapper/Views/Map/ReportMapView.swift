import SwiftUI
import MapKit

/// Tab 2: every neighbor's report as a pin. Tap a pin to open it.
struct ReportMapView: View {
    @Binding var focusedReportID: Report.ID?

    @Environment(ReportStore.self) private var store
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedID: Report.ID?

    var body: some View {
        // System balloon markers: their tip sits on the coordinate, so a report
        // posted where you're standing stays tappable above the blue location dot.
        Map(position: $position, selection: $selectedID) {
            UserAnnotation()
            ForEach(store.reports) { report in
                Marker(
                    report.primaryClass?.title ?? "Report",
                    systemImage: report.primaryClass?.symbol ?? "mappin",
                    coordinate: report.coordinate
                )
                .tint(report.primaryClass?.color ?? .red)
                .annotationTitles(.hidden)
                .tag(report.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .overlay(alignment: .top) {
            Text(countText)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
        }
        .sheet(isPresented: isShowingReport) {
            if let selectedID {
                ReportDetailView(reportID: selectedID)
                    .id(selectedID)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    // Keep the map live behind the sheet so another pin can be tapped.
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        }
        .onChange(of: focusedReportID, initial: true) { _, id in
            guard let id, let report = store.report(id: id) else { return }
            withAnimation {
                position = .region(MKCoordinateRegion(
                    center: report.coordinate,
                    latitudinalMeters: 600,
                    longitudinalMeters: 600
                ))
            }
            focusedReportID = nil
            // Let the Review cover finish dismissing before presenting the sheet.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { selectedID = report.id }
        }
    }

    private var isShowingReport: Binding<Bool> {
        Binding(
            get: { selectedID != nil },
            set: { if !$0 { selectedID = nil } }
        )
    }

    private var countText: String {
        let n = store.reports.count
        switch n {
        case 0: return "All clear so far"
        case 1: return "1 report from neighbors"
        default: return "\(n) reports from neighbors"
        }
    }
}
