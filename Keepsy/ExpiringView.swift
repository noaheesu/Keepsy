import SwiftUI

struct ExpiringView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.expiresAt)], predicate: Self.predicate(dated: true, query: ""))
    private var datedBatches: FetchedResults<Batch>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.addedAt, order: .reverse)], predicate: Self.predicate(dated: false, query: ""))
    private var undatedBatches: FetchedResults<Batch>
    @State private var query = ""
    @State private var target: EditorTarget?
    @State private var showingSettings = false

    var body: some View {
        let groups = Dictionary(grouping: datedBatches) { Expiry.Urgency(daysLeft: Expiry.daysLeft(until: $0.expiresAt ?? .now)) }
        NavigationStack {
            List {
                Section {
                    TodayHeader(dueThisWeek: datedBatches.count - (groups[.overdue]?.count ?? 0) - (groups[.later]?.count ?? 0))
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                ForEach(Expiry.Urgency.allCases, id: \.self) { urgency in
                    if let batches = groups[urgency] {
                        Section {
                            BatchRows(batches: batches, target: $target)
                        } header: {
                            Text(urgency.title)
                                .foregroundStyle(urgency.color)
                        }
                    }
                }
                if !undatedBatches.isEmpty {
                    Section("No expiration") {
                        BatchRows(batches: Array(undatedBatches), target: $target)
                    }
                }
            }
            .overlay {
                if datedBatches.isEmpty && undatedBatches.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Keepsy")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Is it at home?"))
            .onChange(of: query) { applyFilters() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") { target = .new(nil) }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $target) { target in
                BatchEditor(target: target)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            ContentUnavailableView {
                Label("No items yet", systemImage: "refrigerator")
            } description: {
                Text("Add what's in your fridge and cupboards to see what to use first.")
            } actions: {
                Button("Add Item") { target = .new(nil) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func applyFilters() {
        datedBatches.nsPredicate = Self.predicate(dated: true, query: query)
        undatedBatches.nsPredicate = Self.predicate(dated: false, query: query)
    }

    private static func predicate(dated: Bool, query: String) -> NSPredicate {
        var parts = [NSPredicate(format: dated ? "expiresAt != nil" : "expiresAt == nil")]
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            parts.append(NSPredicate(format: "item.name CONTAINS[cd] %@", trimmed))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }
}

/// Today's date and how much needs using this week, kept short so the list starts high on screen.
private struct TodayHeader: View {
    let dueThisWeek: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Group {
                if dueThisWeek == 0 {
                    Text("Nothing runs out this week")
                } else {
                    Text("\(dueThisWeek) to use this week")
                }
            }
            .font(.stamp(.title3))
        }
    }
}

#Preview {
    ExpiringView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
