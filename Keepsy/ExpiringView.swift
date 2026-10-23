import SwiftUI

struct ExpiringView: View {
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.expiresAt)], predicate: Self.predicate(dated: true, query: "", place: nil))
    private var datedBatches: FetchedResults<Batch>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Batch.addedAt, order: .reverse)], predicate: Self.predicate(dated: false, query: "", place: nil))
    private var undatedBatches: FetchedResults<Batch>
    @FetchRequest(sortDescriptors: [SortDescriptor(\Location.sortOrder)])
    private var locations: FetchedResults<Location>
    @State private var query = ""
    @State private var place: Location?
    @State private var target: EditorTarget?
    @State private var showingSettings = false

    var body: some View {
        let groups = Dictionary(grouping: datedBatches) { Expiry.Urgency(daysLeft: Expiry.daysLeft(until: $0.expiresAt ?? .now)) }
        NavigationStack {
            List {
                Section {
                    WeekSummary(dates: datedBatches.compactMap(\.expiresAt), overdue: groups[.overdue]?.count ?? 0)
                        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if locations.count > 1 {
                        PlaceFilter(locations: Array(locations), selection: $place)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
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
            .onChange(of: place) { applyFilters() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Item", systemImage: "plus") { target = .new(place) }
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
        } else if place != nil {
            ContentUnavailableView("Nothing here", systemImage: "tray")
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
        datedBatches.nsPredicate = Self.predicate(dated: true, query: query, place: place)
        undatedBatches.nsPredicate = Self.predicate(dated: false, query: query, place: place)
    }

    private static func predicate(dated: Bool, query: String, place: Location?) -> NSPredicate {
        var parts = [NSPredicate(format: dated ? "expiresAt != nil" : "expiresAt == nil")]
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            parts.append(NSPredicate(format: "item.name CONTAINS[cd] %@", trimmed))
        }
        if let place {
            // Locations are at most three levels deep, so this covers every descendant.
            parts.append(NSPredicate(format: "location == %@ OR location.parent == %@ OR location.parent.parent == %@", place, place, place))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: parts)
    }
}

/// Today's date, how much needs using this week, and a seven-day strip of what runs out when.
private struct WeekSummary: View {
    let dates: [Date]
    let overdue: Int

    var body: some View {
        let counts = Expiry.dueCounts(dates)
        let dueThisWeek = counts.reduce(0, +)
        VStack(alignment: .leading, spacing: 12) {
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
                .font(.stamp(.title2))
                if overdue > 0 {
                    Text("\(overdue) past date")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.overdue)
                }
            }
            HStack(spacing: 0) {
                ForEach(counts.indices, id: \.self) { offset in
                    DayColumn(offset: offset, count: counts[offset])
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 4)
    }
}

private struct DayColumn: View {
    let offset: Int
    let count: Int

    var body: some View {
        let day = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        let isToday = offset == 0
        VStack(spacing: 4) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2)
                .foregroundStyle(isToday ? Color(.systemBackground) : .secondary)
            Text(verbatim: "\(Calendar.current.component(.day, from: day))")
                .font(.stamp(.subheadline))
                .foregroundStyle(isToday ? Color(.systemBackground) : .primary)
            HStack(spacing: 2) {
                ForEach(0..<min(count, 3), id: \.self) { _ in
                    Circle().frame(width: 5, height: 5)
                }
            }
            .frame(height: 5)
            .foregroundStyle(isToday ? Color(.systemBackground) : Expiry.color(daysLeft: offset))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(isToday ? Color.accentColor : Color.clear, in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(day.formatted(.dateTime.weekday(.wide).day())), \(count) items"))
    }
}

/// Horizontal chips to narrow the list to one place and everything inside it.
private struct PlaceFilter: View {
    let locations: [Location]
    @Binding var selection: Location?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(Text("All"), isOn: selection == nil) { selection = nil }
                ForEach(locations.sorted { $0.treeOrder.lexicographicallyPrecedes($1.treeOrder) }) { location in
                    chip(Text(location.name ?? ""), isOn: selection == location) { selection = location }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }

    private func chip(_ title: Text, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            title
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color(.systemBackground) : .primary)
                .background(isOn ? Color.accentColor : Color(.secondarySystemFill), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    ExpiringView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
