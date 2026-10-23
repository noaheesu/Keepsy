import CoreData

extension Location {
    static let maxDepth = 3

    var path: String {
        [parent?.path, name].compactMap { $0 }.joined(separator: " › ")
    }

    var depth: Int { parent.map { $0.depth + 1 } ?? 1 }

    var canHaveChildren: Bool { depth < Self.maxDepth }

    /// Sort key that lists the tree depth-first: Kitchen, Kitchen › Fridge, Kitchen › Freezer, Bathroom…
    var treeOrder: [Int16] { (parent?.treeOrder ?? []) + [sortOrder] }

    @discardableResult
    static func make(_ name: String, parent: Location?, in context: NSManagedObjectContext) -> Location {
        let siblings = Location.fetchRequest()
        siblings.predicate = parent.map { NSPredicate(format: "parent == %@", $0) } ?? NSPredicate(format: "parent == nil")
        let order = (try? context.count(for: siblings)) ?? 0
        let location = Location(context: context)
        location.id = UUID()
        location.name = name
        location.parent = parent
        location.sortOrder = Int16(order)
        return location
    }

    /// Deleting never loses things: batches and sub-locations move up to the parent.
    func deleteMovingContents() {
        for batch in (batches as? Set<Batch>) ?? [] {
            batch.location = parent
        }
        for child in (children as? Set<Location>) ?? [] {
            child.parent = parent
        }
        managedObjectContext?.delete(self)
    }
}
