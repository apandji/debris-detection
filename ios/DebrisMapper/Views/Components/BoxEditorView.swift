import SwiftUI

/// Move, resize, relabel, and add boxes on a photo. Works on a copy;
/// the caller decides what Done means (draft edit vs. neighbor correction).
struct BoxEditorView: View {
    let image: UIImage?
    /// Which boxes can be removed here (e.g. only ones added in this session).
    let canDelete: (Detection) -> Bool
    let onDone: ([Detection]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var detections: [Detection]
    @State private var selectedID: Detection.ID?

    init(
        image: UIImage?,
        detections: [Detection],
        canDelete: @escaping (Detection) -> Bool,
        onDone: @escaping ([Detection]) -> Void
    ) {
        self.image = image
        self.canDelete = canDelete
        self.onDone = onDone
        _detections = State(initialValue: detections)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                canvas
                inspector
                Spacer(minLength: 0)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Boxes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone(detections)
                        dismiss()
                    }
                    .bold()
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(action: addBox) {
                        Label("Add Box", systemImage: "plus.viewfinder")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
    }

    private var canvas: some View {
        DetectionPhoto(image: image, detections: [])
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { selectedID = nil }
                        ForEach($detections) { $d in
                            EditableBox(
                                box: $d.box,
                                label: d.label,
                                size: geo.size,
                                isSelected: selectedID == d.id,
                                onSelect: { selectedID = d.id }
                            )
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
    }

    @ViewBuilder
    private var inspector: some View {
        if let i = detections.firstIndex(where: { $0.id == selectedID }) {
            HStack {
                Picker("Label", selection: $detections[i].label) {
                    ForEach(DebrisClass.allCases) { c in
                        Label(c.title, systemImage: c.symbol).tag(c)
                    }
                }
                .pickerStyle(.menu)
                Spacer()
                if canDelete(detections[i]) {
                    Button(role: .destructive) {
                        detections.remove(at: i)
                        selectedID = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete box")
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Text("Tap a box to relabel it. Drag to move, pull a corner to resize. Missed something? Add a box.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
    }

    private func addBox() {
        let new = Detection(
            label: .fallenTree,
            box: BoundingBox(x: 0.3, y: 0.3, w: 0.4, h: 0.4),
            source: .person
        )
        detections.append(new)
        selectedID = new.id
    }
}

/// One draggable, resizable box. Coordinates stay normalized (0–1).
private struct EditableBox: View {
    @Binding var box: BoundingBox
    let label: DebrisClass
    let size: CGSize
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var start: BoundingBox?

    private static let minSide = 0.05

    private enum Corner: CaseIterable { case topLeading, topTrailing, bottomLeading, bottomTrailing }

    var body: some View {
        let rect = CGRect(x: box.x * size.width, y: box.y * size.height,
                          width: box.w * size.width, height: box.h * size.height)
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(label.color.opacity(isSelected ? 0.25 : 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(label.color, lineWidth: isSelected ? 3 : 2)
                )
                .overlay(alignment: .topLeading) {
                    Text(label.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(label.color, in: Capsule())
                        .foregroundStyle(.black)
                        .padding(4)
                }
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(moveGesture)

            if isSelected {
                ForEach(Corner.allCases, id: \.self) { corner in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(label.color, lineWidth: 2))
                        .frame(width: 18, height: 18)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .position(point(for: corner, in: rect))
                        .gesture(resizeGesture(corner))
                }
            }
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                onSelect()
                let s = start ?? box
                start = s
                box.x = clamp(s.x + Double(v.translation.width / size.width), 0, 1 - s.w)
                box.y = clamp(s.y + Double(v.translation.height / size.height), 0, 1 - s.h)
            }
            .onEnded { _ in start = nil }
    }

    private func resizeGesture(_ corner: Corner) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let s = start ?? box
                start = s
                let dx = Double(v.translation.width / size.width)
                let dy = Double(v.translation.height / size.height)
                var left = s.x, top = s.y, right = s.x + s.w, bottom = s.y + s.h
                switch corner {
                case .topLeading: left += dx; top += dy
                case .topTrailing: right += dx; top += dy
                case .bottomLeading: left += dx; bottom += dy
                case .bottomTrailing: right += dx; bottom += dy
                }
                left = clamp(left, 0, right - Self.minSide)
                top = clamp(top, 0, bottom - Self.minSide)
                right = clamp(right, left + Self.minSide, 1)
                bottom = clamp(bottom, top + Self.minSide, 1)
                box = BoundingBox(x: left, y: top, w: right - left, h: bottom - top)
            }
            .onEnded { _ in start = nil }
    }

    private func point(for corner: Corner, in rect: CGRect) -> CGPoint {
        switch corner {
        case .topLeading: CGPoint(x: rect.minX, y: rect.minY)
        case .topTrailing: CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeading: CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomTrailing: CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(v, lo), hi)
    }
}
