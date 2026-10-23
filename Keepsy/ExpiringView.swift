import SwiftUI

struct ExpiringView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.expiresAt)], predicate: Self.predicate(dated: true, query: ""))
    private var datedBatches: FetchedResults<Batch>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.addedAt, order: .reverse)], predicate: Self.predicate(dated: false, query: ""))
    private var undatedBatches: FetchedResults<Batch>
    @State private var query = ""
    @State private var editing: Batch?
    @State private var adding = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BatchRows(batches: datedBatches, editing: $editing)
                }
                if !undatedBatches.isEmpty {
                    Section("No expiration") {
                        BatchRows(batches: undatedBatches, editing: $editing)
                    }
                }
            }
            .overlay {
                if datedBatches.isEmpty && undatedBatches.isEmpty {
                    if query.isEmpty {
                        ContentUnavailableView("No items yet", systemImage: "refrigerator")
                    } else {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .searchable(text: $query)
            .onChange(of: query) {
                datedBatches.nsPredicate = Self.predicate(dated: true, query: query)
                undatedBatches.nsPredicate = Self.predicate(dated: false, query: query)
            }
            .navigationTitle("Keepsy")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") { adding = true }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $adding) {
                BatchEditor(batch: nil)
            }
            .sheet(item: $editing) { batch in
                BatchEditor(batch: batch)
            }
        }
    }

    private static func predicate(dated: Bool, query: String) -> NSPredicate {
        let expiry = NSPredicate(format: dated ? "expiresAt != nil" : "expiresAt == nil")
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return expiry }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [expiry, NSPredicate(format: "item.name CONTAINS[cd] %@", trimmed)])
    }
}

/// Tappable batch rows with quick "used one" / "bought again" swipes; the owning list presents the editor for `editing`.
struct BatchRows: View {
    let batches: FetchedResults<Batch>
    @Binding var editing: Batch?
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        ForEach(batches) { batch in
            Button { editing = batch } label: {
                BatchRow(batch: batch)
            }
            .tint(.primary)
            .swipeActions(edge: .trailing) {
                Button("Used", systemImage: "checkmark") {
                    batch.useOne()
                    try? context.save()
                }
                .tint(.green)
            }
            .swipeActions(edge: .leading) {
                if let item = batch.item {
                    Button("Bought Again", systemImage: "arrow.clockwise") {
                        _ = try? item.restock(in: context)
                    }
                    .tint(.blue)
                }
            }
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
        let location = Text(batch.location?.path ?? "")
        guard let level = Level(rawValue: batch.level), level != .full, let updated = batch.levelUpdatedAt else {
            return location
        }
        return Text("\(location) · \(Text(level.title)) · \(Text(updated, format: .relative(presentation: .named)))")
    }
}

#Preview {
    ExpiringView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
