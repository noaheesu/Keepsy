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
        let item = try batch.item ?? existingItem(in: context) ?? newItem(in: context)
        item.name = trimmedName
        if existing != nil || photo != nil {
            item.photo = photo
        }
        batch.item = item
        batch.location = location
        batch.expiresAt = hasExpiry ? expiresAt : nil
        batch.quantity = Int16(quantity)
        if existing == nil || batch.level != level.rawValue {
            batch.level = level.rawValue
            batch.levelUpdatedAt = .now
        }
        try context.save()
        return batch
    }

    private func existingItem(in context: NSManagedObjectContext) throws -> Item? {
        let request = Item.fetchRequest()
        request.predicate = NSPredicate(format: "name =[c] %@", trimmedName)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func newItem(in context: NSManagedObjectContext) -> Item {
        let item = Item(context: context)
        item.id = UUID()
        item.createdAt = .now
        return item
    }
}
