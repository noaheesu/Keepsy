import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Batch.expiresAt)],
        predicate: NSPredicate(format: "expiresAt != nil")
    )
    private var datedBatches: FetchedResults<Batch>
    @FetchRequest(
        sortDescriptors: [SortDescriptor(\Batch.addedAt, order: .reverse)],
        predicate: NSPredicate(format: "expiresAt == nil")
    )
    private var undatedBatches: FetchedResults<Batch>
    @State private var editing: Batch?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    rows(datedBatches)
                }
                if !undatedBatches.isEmpty {
                    Section("No expiration") {
                        rows(undatedBatches)
                    }
                }
            }
            .overlay {
                if datedBatches.isEmpty && undatedBatches.isEmpty {
                    ContentUnavailableView("No items yet", systemImage: "refrigerator")
                }
            }
            .navigationTitle("Keepsy")
            .toolbar {
                Button("Add Item", systemImage: "plus") { adding = true }
            }
            .sheet(isPresented: $adding) {
                BatchEditor(batch: nil)
            }
            .sheet(item: $editing) { batch in
                BatchEditor(batch: batch)
            }
        }
    }

    private func rows(_ batches: FetchedResults<Batch>) -> some View {
        ForEach(batches) { batch in
            Button { editing = batch } label: {
                BatchRow(batch: batch)
            }
            .tint(.primary)
        }
        .onDelete { offsets in
            offsets.map { batches[$0] }.forEach(context.delete)
            try? context.save()
        }
    }
}

struct BatchRow: View {
    @ObservedObject var batch: Batch
    @ScaledMetric private var thumbnailSide = 36.0

    var body: some View {
        HStack {
            // shortcut: decodes the (already downscaled) photo on every render, cache if scrolling gets janky.
            if let data = batch.item?.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbnailSide, height: thumbnailSide)
                    .clipShape(.rect(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                HStack(spacing: 4) {
                    Text(batch.item?.name ?? "")
                    if batch.quantity > 1 {
                        Text(verbatim: "×\(batch.quantity)")
                            .foregroundStyle(.secondary)
                    }
                }
                detail
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let expiresAt = batch.expiresAt {
                let days = Expiry.daysLeft(until: expiresAt)
                Text(Expiry.label(daysLeft: days))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Expiry.color(daysLeft: days))
            }
        }
    }

    private var detail: Text {
        let location = Text(batch.item?.location?.path ?? "")
        guard let level = Level(rawValue: batch.level), level != .full, let updated = batch.levelUpdatedAt else {
            return location
        }
        return Text("\(location) · \(Text(level.title)) · \(Text(updated, format: .relative(presentation: .named)))")
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
