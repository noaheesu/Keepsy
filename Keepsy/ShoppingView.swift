import SwiftUI

struct ShoppingView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\ShoppingEntry.isDone), SortDescriptor(\ShoppingEntry.createdAt)])
    private var entries: FetchedResults<ShoppingEntry>
    @State private var suggestions: [Item] = []
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Add to list", text: $newName)
                        .submitLabel(.done)
                        .onSubmit {
                            try? Shopping.add(newName, in: context)
                            newName = ""
                        }
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)
                    }
                    .onDelete { offsets in
                        offsets.map { entries[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                }
                if !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions) { item in
                            Button {
                                try? Shopping.add(item.name ?? "", item: item, in: context)
                            } label: {
                                Label(item.name ?? "", systemImage: "plus.circle")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping")
            .toolbar {
                if entries.contains(where: \.isDone) {
                    Button("Clear Done") {
                        entries.filter(\.isDone).forEach(context.delete)
                        try? context.save()
                    }
                }
            }
            .task { refreshSuggestions() }
            // Suggestions depend on batches and entries anywhere in the store, which no single fetch request tracks.
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { _ in
                refreshSuggestions()
            }
        }
    }

    private func refreshSuggestions() {
        suggestions = (try? Shopping.suggestions(in: context)) ?? []
    }
}

struct EntryRow: View {
    @ObservedObject var entry: ShoppingEntry
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        Button {
            entry.isDone.toggle()
            try? context.save()
        } label: {
            Label {
                Text(entry.name ?? "")
                    .strikethrough(entry.isDone)
                    .foregroundStyle(entry.isDone ? .secondary : .primary)
            } icon: {
                Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
            }
        }
        .accessibilityAddTraits(entry.isDone ? .isSelected : [])
    }
}

#Preview {
    ShoppingView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
