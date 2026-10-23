import SwiftUI

/// One level of the location tree: sub-locations, then the batches stored directly here.
/// `parent == nil` is the top level, whose batches are the ones without a location.
struct LocationList: View {
    let parent: Location?

    @Environment(\.managedObjectContext) private var context
    @FetchRequest private var children: FetchedResults<Location>
    @FetchRequest private var batches: FetchedResults<Batch>
    @State private var editing: Batch?
    @State private var addingItem = false
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
                        NavigationLink(child.name ?? "", value: child)
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    child.deleteMovingContents()
                                    try? context.save()
                                }
                                Button("Rename") { startNaming(child) }
                            }
                    }
                    .onMove(perform: move)
                }
            }
            if !batches.isEmpty {
                Section(parent == nil ? "No location" : "Items") {
                    BatchRows(batches: batches, editing: $editing)
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
                    Button("Add Item", systemImage: "cart.badge.plus") { addingItem = true }
                    if parent?.canHaveChildren ?? true {
                        Button("Add Location", systemImage: "folder.badge.plus") { startNaming(nil) }
                    }
                }
            }
        }
        .sheet(isPresented: $addingItem) {
            BatchEditor(batch: nil, location: parent)
        }
        .sheet(item: $editing) { batch in
            BatchEditor(batch: batch)
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

#Preview {
    NavigationStack {
        LocationList(parent: nil)
            .navigationDestination(for: Location.self) { LocationList(parent: $0) }
    }
    .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
