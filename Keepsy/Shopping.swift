import CoreData

enum Shopping {
    /// Items worth rebuying: nothing usable left at home (used up, empty or expired) and not already on the list.
    static func suggestions(in context: NSManagedObjectContext, now: Date = .now) throws -> [Item] {
        let open = ShoppingEntry.fetchRequest()
        open.predicate = NSPredicate(format: "isDone == NO")
        let listed = Set(try context.fetch(open).compactMap(\.item))
        return try context.fetch(Item.fetchRequest())
            .filter { item in
                !listed.contains(item) && !((item.batches as? Set<Batch>) ?? []).contains { isUsable($0, now: now) }
            }
            .sorted { ($0.name ?? "").localizedStandardCompare($1.name ?? "") == .orderedAscending }
    }

    static func isUsable(_ batch: Batch, now: Date) -> Bool {
        guard batch.level != Level.empty.rawValue else { return false }
        return batch.expiresAt.map { Expiry.daysLeft(until: $0, from: now) >= 0 } ?? true
    }

    /// Typed names link to a known item so it drops out of suggestions.
    static func add(_ name: String, item: Item? = nil, in context: NSManagedObjectContext) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = ShoppingEntry(context: context)
        entry.id = UUID()
        entry.name = trimmed
        entry.createdAt = .now
        entry.item = try item ?? Item.named(trimmed, in: context)
        try context.save()
    }
}
