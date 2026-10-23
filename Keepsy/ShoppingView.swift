import SwiftUI

struct ShoppingView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\ShoppingEntry.isDone), SortDescriptor(\ShoppingEntry.createdAt)])
    private var entries: FetchedResults<ShoppingEntry>
    @State private var suggestions: [Item] = []
    @State private var newName = ""

    var body: some View {
        let doneCount = entries.filter(\.isDone).count
        NavigationStack {
            List {
                if !suggestions.isEmpty {
                    Section {
                        SuggestionChips(items: suggestions) { item in
                            withAnimation { try? Shopping.add(item.name ?? "", item: item, in: context) }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    } header: {
                        Text("Ran out or past date. Buy again?")
                    }
                }
                Section {
                    HStack {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityHidden(true)
                        TextField("Add to list", text: $newName)
                            .submitLabel(.done)
                            .onSubmit {
                                withAnimation { try? Shopping.add(newName, in: context) }
                                newName = ""
                            }
                    }
                    ForEach(entries) { entry in
                        EntryRow(entry: entry)
                    }
                    .onDelete { offsets in
                        offsets.map { entries[$0] }.forEach(context.delete)
                        try? context.save()
                    }
                }
            }
            .overlay {
                if entries.isEmpty && suggestions.isEmpty {
                    ContentUnavailableView {
                        Label("Your list is empty", systemImage: "cart")
                    } description: {
                        Text("Type what you need above. Things you mark as used show up here as suggestions.")
                    }
                    .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if doneCount > 0 {
                    Button {
                        withAnimation {
                            do {
                                try Shopping.putAway(in: context)
                            } catch {
                                context.rollback()
                            }
                        }
                    } label: {
                        Label("Put Away (\(doneCount))", systemImage: "house")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Shopping")
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

private struct SuggestionChips: View {
    let items: [Item]
    let add: (Item) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button { add(item) } label: {
                        Label(item.name ?? "", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(Color.accentColor)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

struct EntryRow: View {
    @ObservedObject var entry: ShoppingEntry
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        Button {
            withAnimation {
                entry.isDone.toggle()
                try? context.save()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: entry.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(entry.isDone ? Color.accentColor : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                Text(entry.name ?? "")
                    .strikethrough(entry.isDone)
                    .foregroundStyle(entry.isDone ? .secondary : .primary)
                Spacer()
                if entry.item != nil {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .accessibilityLabel(Text("Bought before"))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(entry.isDone ? .isSelected : [])
    }
}

#Preview {
    ShoppingView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
