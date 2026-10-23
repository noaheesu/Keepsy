import SwiftUI

/// One level of the location tree: sub-locations, then the batches stored directly here.
/// `parent == nil` is the top level, whose batches are the ones without a location.
struct LocationList: View {
    let parent: Location?

    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var children: FetchedResults<Location>
    @FetchRequest private var batches: FetchedResults<Batch>
    @State private var target: EditorTarget?
    @State private var naming = false
    @State private var renaming: Location?
    @State private var nameDraft = ""

    init(parent: Location?) {
        self.parent = parent
        _children = FetchRequest(
            sortDescriptors: [SortDescriptor(\Location.sortOrder), SortDescriptor(\Location.name)],
            predicate: parent.map { NSPredicate(format: "parent == %@", $0) } ?? NSPredicate(format: "parent == nil")
        )
        _batches = FetchRequest(
            sortDescriptors: [SortDescriptor(\Batch.expiresAt)],
            predicate: parent.map { NSPredicate(format: "location == %@", $0) } ?? NSPredicate(format: "location == nil")
        )
    }

    var body: some View {
        List {
            if !children.isEmpty {
                Section {
                    ForEach(children) { child in
                        NavigationLink(value: child) {
                            LocationRow(location: child)
                        }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    child.deleteMovingContents()
                                    try? context.save()
                                }
                                Button("Rename") { startNaming(child) }
                            }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") { startNaming(child) }
                                Toggle("Freezer", systemImage: "snowflake", isOn: Binding {
                                    child.isFreezer
                                } set: {
                                    child.isFreezer = $0
                                    try? context.save()
                                })
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    child.deleteMovingContents()
                                    try? context.save()
                                }
                            }
                    }
                    .onMove(perform: move)
                }
            }
            if !batches.isEmpty {
                Section(parent == nil ? "No location" : "Items") {
                    BatchRows(batches: Array(batches), target: $target)
                }
            }
        }
        .overlay {
            if children.isEmpty && batches.isEmpty {
                ContentUnavailableView("Nothing here", systemImage: "tray")
            }
        }
        .navigationTitle(parent?.name ?? String(localized: "Locations"))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if children.count > 1 {
                    EditButton()
                }
                Menu("Add", systemImage: "plus") {
                    Button("Add Item", systemImage: "cart.badge.plus") { target = .new(parent) }
                    if parent?.canHaveChildren ?? true {
                        Button("Add Location", systemImage: "folder.badge.plus") { startNaming(nil) }
                    }
                }
            }
        }
        .sheet(item: $target) { target in
            BatchEditor(target: target)
        }
        .alert(renaming == nil ? "Add Location" : "Rename", isPresented: $naming) {
            TextField("Name", text: $nameDraft)
            Button("Save", action: saveName)
            Button("Cancel", role: .cancel) {}
        }
    }

    private func startNaming(_ location: Location?) {
        renaming = location
        nameDraft = location?.name ?? ""
        naming = true
    }

    private func saveName() {
        let name = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let renaming {
            renaming.name = name
        } else {
            Location.make(name, parent: parent, in: context)
        }
        try? context.save()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = Array(children)
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, location) in ordered.enumerated() {
            location.sortOrder = Int16(index)
        }
        try? context.save()
    }
}

private struct LocationRow: View {
    @ObservedObject var location: Location

    var body: some View {
        let batches = location.allBatches
        let soonest = batches.compactMap(\.expiresAt).min()
        HStack(spacing: 12) {
            Image(systemName: location.isFreezer ? "snowflake" : location.children?.count ?? 0 > 0 ? "square.stack.3d.up" : "shippingbox")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name ?? "")
                    .font(.body.weight(.semibold))
                Text("\(batches.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let soonest {
                let days = Expiry.daysLeft(until: soonest)
                Text(Expiry.label(daysLeft: days))
                    .font(.stamp(.subheadline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(Expiry.color(daysLeft: days))
                    .accessibilityLabel(Text("Soonest \(Expiry.label(daysLeft: days))"))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        LocationList(parent: nil)
            .navigationDestination(for: Location.self) { LocationList(parent: $0) }
    }
    .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
