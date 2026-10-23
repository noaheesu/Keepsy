import CoreData

struct WasteStats {
    struct Entry: Identifiable {
        let name: String
        let count: Int

        var id: String { name }
    }

    var used = 0
    var wasted = 0
    /// Most often thrown away first.
    var topWasted: [Entry] = []

    var total: Int { used + wasted }
    var wastedShare: Double { total == 0 ? 0 : Double(wasted) / Double(total) }
}

enum Waste {
    static let periodDays = 30

    static func stats(in context: NSManagedObjectContext, now: Date = .now, limit: Int = 5) throws -> WasteStats {
        let request = UsageEvent.fetchRequest()
        request.predicate = NSPredicate(format: "at >= %@", now.addingTimeInterval(-Double(periodDays) * 86_400) as NSDate)
        let events = try context.fetch(request)
        var stats = WasteStats()
        var counts: [String: Int] = [:]
        for event in events {
            guard event.wasted else {
                stats.used += 1
                continue
            }
            stats.wasted += 1
            // Events of deleted items keep counting in the totals but have no name to list.
            if let name = event.item?.name { counts[name, default: 0] += 1 }
        }
        let ranked = counts
            .map { WasteStats.Entry(name: $0.key, count: $0.value) }
            .sorted { (a: WasteStats.Entry, b: WasteStats.Entry) -> Bool in
                a.count != b.count ? a.count > b.count : a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        stats.topWasted = Array(ranked.prefix(limit))
        return stats
    }
}
