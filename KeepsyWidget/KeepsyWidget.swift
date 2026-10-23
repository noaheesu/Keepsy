import SwiftUI
import WidgetKit

struct ExpiringEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct ExpiringProvider: TimelineProvider {
    func placeholder(in context: Context) -> ExpiringEntry {
        ExpiringEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (ExpiringEntry) -> Void) {
        let snapshot = WidgetSnapshot.load()
        completion(ExpiringEntry(date: .now, snapshot: context.isPreview && snapshot.entries.isEmpty ? .sample : snapshot))
    }

    /// One entry per midnight for a week so the days left tick down without the app; the app reloads on every change.
    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<ExpiringEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let today = Calendar.current.startOfDay(for: .now)
        let midnights = (1...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
        let entries = [ExpiringEntry(date: .now, snapshot: snapshot)] + midnights.map { ExpiringEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ExpiringWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ExpiringEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Expiring soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            if entry.snapshot.entries.isEmpty {
                Spacer()
                Text("Nothing to use up soon")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                ForEach(entry.snapshot.entries.prefix(family == .systemSmall ? 3 : 4), id: \.self) { item in
                    let daysLeft = Expiry.daysLeft(until: item.expiresAt, from: entry.date)
                    HStack {
                        Text(item.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Expiry.label(daysLeft: daysLeft))
                            .font(.system(.caption, weight: .heavy).width(.expanded))
                            .foregroundStyle(Expiry.color(daysLeft: daysLeft))
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.background, for: .widget)
    }
}

struct ExpiringWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Expiring", provider: ExpiringProvider()) { entry in
            ExpiringWidgetView(entry: entry)
        }
        .configurationDisplayName("Expiring soon")
        .description("What to use first.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct KeepsyWidgets: WidgetBundle {
    var body: some Widget {
        ExpiringWidget()
    }
}

extension WidgetSnapshot {
    static let sample = WidgetSnapshot(entries: [("Milk", 0), ("Tofu", 1), ("Eggs", 3), ("Yogurt", 5)].map { name, days in
        Entry(name: name, expiresAt: Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now)
    })
}

#Preview(as: .systemSmall) {
    ExpiringWidget()
} timeline: {
    ExpiringEntry(date: .now, snapshot: .sample)
    ExpiringEntry(date: .now, snapshot: WidgetSnapshot())
}
