import CoreData

struct Suggestion: Identifiable {
    enum Reason: Equatable {
        case ranOut
        /// Usually bought every this many days, and that long has passed.
        case usual(days: Int)
    }

    let item: Item
    let reason: Reason

    var id: NSManagedObjectID { item.objectID }
}

enum Shopping {
    /// Items worth rebuying and not already on the list: nothing usable left at home (used up, empty or expired),
    /// or it is about the time it usually gets bought again.
    static func suggestions(in context: NSManagedObjectContext, now: Date = .now) throws -> [Suggestion] {
        let open = ShoppingEntry.fetchRequest()
        open.predicate = NSPredicate(format: "isDone == NO")
        let listed = Set(try context.fetch(open).compactMap(\.item))
        return try context.fetch(Item.fetchRequest())
            .filter { !listed.contains($0) }
            .compactMap { item -> Suggestion? in
                if !((item.batches as? Set<Batch>) ?? []).contains(where: { isUsable($0, now: now) }) {
                    return Suggestion(item: item, reason: .ranOut)
                }
                if item.restockDays > 0, let last = item.lastBoughtAt,
                   now.timeIntervalSince(last) / 86_400 >= item.restockDays {
                    return Suggestion(item: item, reason: .usual(days: max(1, Int(item.restockDays.rounded()))))
                }
                return nil
            }
            .sorted { ($0.item.name ?? "").localizedStandardCompare($1.item.name ?? "") == .orderedAscending }
    }

    static func isUsable(_ batch: Batch, now: Date) -> Bool {
        guard batch.level != Level.empty.rawValue else { return false }
        return batch.expiresAt.map { Expiry.daysLeft(until: $0, from: now) >= 0 } ?? true
    }

    /// Bought items go back into stock, where and for as long as last time.
    /// Returns the never-stocked ones, which still need a place and a date.
    @discardableResult
    static func putAway(in context: NSManagedObjectContext) throws -> [Batch] {
        var new: [Batch] = []
        let done = ShoppingEntry.fetchRequest()
        done.predicate = NSPredicate(format: "isDone == YES")
        for entry in try context.fetch(done) {
            if let item = entry.item {
                let batch = try item.restock(in: context)
                // The date is a guess from last time until someone looks at the package.
                if batch.expiresAt != nil { batch.needsDateCheck = true }
            } else if let name = entry.name {
                // Never stocked before: nothing to copy, so it goes in without a date and asks for one.
                var draft = BatchDraft()
                draft.name = name
                draft.hasExpiry = false
                let batch = try draft.save(to: nil, in: context)
                batch.needsDateCheck = true
                new.append(batch)
            }
            context.delete(entry)
        }
        try context.save()
        return new
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
