import SwiftUI
import MapKit

/// Tab 2: every neighbor's report as a pin. Tap a pin to open it.
struct ReportMapView: View {
    @Binding var focusedReportID: Report.ID?

    @Environment(ReportStore.self) private var store
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selected: Report?

    var body: some View {
        Map(position: $position) {
            UserAnnotation()
            ForEach(store.reports) { report in
                Annotation(report.primaryClass?.title ?? "Report", coordinate: report.coordinate) {
                    Button { selected = report } label: {
                        ReportPin(report: report, isSelected: selected?.id == report.id)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
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
        .sheet(item: $selected) { report in
            ReportDetailView(reportID: report.id)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { selected = report }
        }
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

struct ReportPin: View {
    let report: Report
    var isSelected = false

    var body: some View {
        let cls = report.primaryClass
        Image(systemName: cls?.symbol ?? "mappin")
            .font(.system(size: isSelected ? 17 : 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: isSelected ? 40 : 32, height: isSelected ? 40 : 32)
            .background(cls?.color ?? .red, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .animation(.snappy, value: isSelected)
    }
}
