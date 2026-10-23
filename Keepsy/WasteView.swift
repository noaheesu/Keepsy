import SwiftUI

struct WasteView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var stats = WasteStats()

    var body: some View {
        Form {
            if stats.total == 0 {
                ContentUnavailableView("Nothing used up yet", systemImage: "chart.bar", description: Text("Swipe items as used up or long-press them as thrown away to see how much gets wasted."))
            } else {
                Section {
                    LabeledContent("Used up", value: stats.used, format: .number)
                    LabeledContent("Thrown away", value: stats.wasted, format: .number)
                    LabeledContent("Wasted", value: stats.wastedShare, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(stats.wastedShare > 0.2 ? Color.overdue : .primary)
                } header: {
                    Text("Last \(Waste.periodDays) days")
                }
                if !stats.topWasted.isEmpty {
                    Section("Thrown away most") {
                        ForEach(stats.topWasted) { entry in
                            LabeledContent(entry.name, value: entry.count, format: .number)
                        }
                    }
                }
            }
        }
        .navigationTitle("Waste")
        .task { stats = (try? Waste.stats(in: context)) ?? WasteStats() }
    }
}

#Preview {
    NavigationStack {
        WasteView()
    }
    .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
