import SwiftUI

/// What the item editor sheet was opened for.
enum EditorTarget: Identifiable {
    case new(Location?)
    case edit(Batch)
    case restock(Item)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let batch): batch.objectID.uriRepresentation().absoluteString
        case .restock(let item): "restock" + item.objectID.uriRepresentation().absoluteString
        }
    }
}

extension Font {
    /// Wide heavy numerals, like a date stamp on a package.
    static func stamp(_ style: Font.TextStyle) -> Font {
        .system(style, weight: .heavy).width(.expanded)
    }
}

/// Tappable batch rows with quick "used one" / "bought again" swipes; the owning list presents the editor for `target`.
struct BatchRows: View {
    let batches: [Batch]
    @Binding var target: EditorTarget?
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        ForEach(batches) { batch in
            Button { target = .edit(batch) } label: {
                BatchRow(batch: batch)
            }
            .tint(.primary)
            .swipeActions(edge: .trailing) {
                Button("Used", systemImage: "checkmark") {
                    withAnimation {
                        batch.useOne()
                        try? context.save()
                    }
                }
                .tint(.fresh)
            }
            .swipeActions(edge: .leading) {
                if let item = batch.item {
                    Button("Bought Again", systemImage: "arrow.clockwise") { target = .restock(item) }
                        .tint(.accentColor)
                }
            }
        }
    }
}

struct BatchRow: View {
    @ObservedObject var batch: Batch
    @ScaledMetric private var thumbnailSide = 44.0

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(batch.item?.name ?? "")
                        .font(.body.weight(.semibold))
                    if batch.quantity > 1 {
                        Text(verbatim: "×\(batch.quantity)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 6) {
                    if let path = batch.location?.path {
                        Text(path)
                    }
                    if let level = Level(rawValue: batch.level), level != .full {
                        LevelGauge(level: level)
                        if let updated = batch.levelUpdatedAt {
                            Text(updated, format: .relative(presentation: .named))
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                if let expiresAt = batch.expiresAt, let addedAt = batch.addedAt {
                    ProgressView(value: Expiry.remaining(addedAt: addedAt, expiresAt: expiresAt))
                        .tint(Expiry.color(daysLeft: Expiry.daysLeft(until: expiresAt)))
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 8)
            if let expiresAt = batch.expiresAt {
                let days = Expiry.daysLeft(until: expiresAt)
                Text(Expiry.label(daysLeft: days))
                    .font(.stamp(.title3))
                    .monospacedDigit()
                    .foregroundStyle(Expiry.color(daysLeft: days))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var thumbnail: some View {
        // shortcut: decodes the (already downscaled) photo on every render, cache if scrolling gets janky.
        if let data = batch.item?.photo, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: thumbnailSide, height: thumbnailSide)
                .clipShape(.rect(cornerRadius: 10))
                .accessibilityHidden(true)
        } else {
            Text(String(batch.item?.name?.prefix(1) ?? ""))
                .font(.stamp(.headline))
                .foregroundStyle(Color.accentColor)
                .frame(width: thumbnailSide, height: thumbnailSide)
                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 10))
                .accessibilityHidden(true)
        }
    }
}

/// Three bars like a battery: full, half, low, empty.
struct LevelGauge: View {
    let level: Level
    @ScaledMetric private var barHeight = 9.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Int(level.rawValue) >= bar ? HierarchicalShapeStyle.primary : .quaternary)
                    .frame(width: barHeight / 2.2, height: barHeight)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(level.title))
    }
}
