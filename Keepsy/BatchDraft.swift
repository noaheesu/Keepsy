import CoreData
import SwiftUI

enum Level: Int16, CaseIterable, Identifiable {
    case empty, low, half, full

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .empty: "Empty"
        case .low: "Low"
        case .half: "Half"
        case .full: "Full"
        }
    }
}

extension Item {
    static func named(_ name: String, in context: NSManagedObjectContext) throws -> Item? {
        let request = Item.fetchRequest()
        request.predicate = NSPredicate(format: "name =[c] %@", name)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Bought again: a new batch where and for as long as last time.
    @discardableResult
    func restock(in context: NSManagedObjectContext) throws -> Batch {
        var draft = BatchDraft()
        draft.fill(from: self)
        return try draft.save(to: nil, in: context)
    }

    /// Learns how often this gets bought, as a running average of the gaps between purchases.
    func recordPurchase(at now: Date = .now) {
        if let last = lastBoughtAt {
            let days = now.timeIntervalSince(last) / 86_400
            // Several batches added the same day are one shopping trip.
            guard days >= 0.5 else { return }
            restockDays = restockDays == 0 ? days : (restockDays + days) / 2
        }
        lastBoughtAt = now
    }
}

extension Batch {
    /// One unit used up or thrown away; the last one removes the batch, which makes the item a shopping suggestion.
    func useOne(wasted: Bool = false) {
        if let context = managedObjectContext {
            let event = UsageEvent(context: context)
            event.id = UUID()
            event.at = .now
            event.wasted = wasted
            event.item = item
        }
        guard quantity > 1 else {
            managedObjectContext?.delete(self)
            return
        }
        quantity -= 1
        level = Level.full.rawValue
        levelUpdatedAt = .now
    }

    func setLevel(_ newLevel: Level) {
        level = newLevel.rawValue
        levelUpdatedAt = .now
    }

    /// Moves into the freezer and gives a month more, counted from today if it had already run out.
    func freeze(into freezer: Location, now: Date = .now) {
        location = freezer
        if let expiresAt {
            self.expiresAt = Calendar.current.date(byAdding: .month, value: 1, to: max(expiresAt, now))
        }
    }
}

/// Editable copy of a batch and its item, written back to Core Data only on save.
struct BatchDraft {
    var name = ""
    var location: Location?
    var hasExpiry = true
    var expiresAt = Date.now
    var quantity = 1
    var level = Level.full
    var photo: Data?

    init(location: Location? = nil) {
        self.location = location
    }

    init(batch: Batch) {
        name = batch.item?.name ?? ""
        location = batch.location
        hasExpiry = batch.expiresAt != nil
        expiresAt = batch.expiresAt ?? .now
        quantity = Int(batch.quantity)
        level = Level(rawValue: batch.level) ?? .full
        photo = batch.item?.photo
    }

    /// Re-adding something bought before: same place, same shelf life counted from today.
    mutating func fill(from item: Item, now: Date = .now) {
        name = item.name ?? name
        location = item.lastLocation
        photo = item.photo
        hasExpiry = item.shelfLifeDays > 0
        expiresAt = Calendar.current.date(byAdding: .day, value: Int(item.shelfLifeDays), to: now) ?? now
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isValid: Bool { !trimmedName.isEmpty }

    @discardableResult
    func save(to existing: Batch?, in context: NSManagedObjectContext) throws -> Batch {
        let batch = existing ?? Batch(context: context)
        if existing == nil {
            batch.id = UUID()
            batch.addedAt = .now
        }
        // A new batch with a known name joins that item, so its history stays in one place.
        let item = try batch.item ?? Item.named(trimmedName, in: context) ?? newItem(in: context)
        item.name = trimmedName
        item.lastLocation = location
        item.shelfLifeDays = hasExpiry ? Int16(clamping: Expiry.daysLeft(until: expiresAt, from: batch.addedAt ?? .now)) : 0
        if existing != nil || photo != nil {
            item.photo = photo
        }
        if existing == nil {
            item.recordPurchase()
        }
        batch.item = item
        batch.location = location
        batch.expiresAt = hasExpiry ? expiresAt : nil
        batch.needsDateCheck = false
        batch.quantity = Int16(quantity)
        if existing == nil || batch.level != level.rawValue {
            batch.level = level.rawValue
            batch.levelUpdatedAt = .now
        }
        try context.save()
        return batch
    }

    private func newItem(in context: NSManagedObjectContext) -> Item {
        let item = Item(context: context)
        item.id = UUID()
        item.createdAt = .now
        return item
    }
}
