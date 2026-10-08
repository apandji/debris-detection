import SwiftUI

extension DebrisClass {
    var color: Color {
        switch self {
        case .fallenTree: .green
        case .damagedBuilding: .orange
        case .rubbleDebris: .brown
        case .downedLineOrPole: .yellow
        case .fireSmoke: .red
        }
    }
}

/// Photo (or placeholder) with normalized detection boxes drawn on top.
struct DetectionPhoto: View {
    let image: UIImage?
    let detections: [Detection]
    /// Box stroke per detection — callers decide what "confirmed" means in context.
    var style: (Detection) -> BoxStyle = { _ in .suggested }

    enum BoxStyle { case suggested, confirmed, rejected }

    var body: some View {
        content
            .overlay {
                GeometryReader { geo in
                    ForEach(detections) { d in
                        box(d, in: geo.size)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            // Seeded demo neighbors have no real photo.
            Rectangle()
                .fill(.quaternary)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay {
                    Image(systemName: detections.first?.label.symbol ?? "photo")
                        .font(.system(size: 56))
                        .foregroundStyle(.tertiary)
                }
        }
    }

    private func box(_ d: Detection, in size: CGSize) -> some View {
        let s = style(d)
        let color: Color = switch s {
        case .suggested: .yellow
        case .confirmed: .green
        case .rejected: .gray
        }
        let rect = CGRect(
            x: d.box.x * size.width,
            y: d.box.y * size.height,
            width: d.box.w * size.width,
            height: d.box.h * size.height
        )
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(color, style: StrokeStyle(lineWidth: 2.5, dash: s == .rejected ? [6, 4] : []))
            .frame(width: rect.width, height: rect.height)
            .overlay(alignment: .topLeading) {
                Text(d.label.title)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color, in: Capsule())
                    .foregroundStyle(.black)
                    .padding(4)
            }
            .opacity(s == .rejected ? 0.6 : 1)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// ✕ / ✓ pair. Tapping the active choice again clears the vote.
struct VoteButtons: View {
    let vote: Bool?
    let onVote: (Bool?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            button(value: false, symbol: "xmark", tint: .red)
            button(value: true, symbol: "checkmark", tint: .green)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: vote)
    }

    private func button(value: Bool, symbol: String, tint: Color) -> some View {
        let active = vote == value
        return Button {
            onVote(active ? nil : value)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(active ? .white : tint)
                .background(active ? tint : tint.opacity(0.12), in: Circle())
        }
        .accessibilityLabel(value ? "Confirm" : "Reject")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
