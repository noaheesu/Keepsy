import CoreData

@MainActor
struct Persistence {
    #if DEBUG
    // Launch with -sampleData to see a populated app in the simulator.
    static let shared = CommandLine.arguments.contains("-sampleData") ? preview : Persistence()
    #else
    static let shared = Persistence()
    #endif

    static let preview: Persistence = {
        let persistence = Persistence(inMemory: true)
        let context = persistence.container.viewContext
        let fridge = try? context.fetch(Location.fetchRequest()).first { $0.name == String(localized: "Fridge") }
        for (name, days, level) in [("Milk", -1, Level.half), ("Tofu", 0, .full), ("Spinach", 1, .low), ("Eggs", 3, .half), ("Yogurt", 5, .full), ("Kimchi", 30, .full)] {
            let item = Item(context: context)
            item.id = UUID()
            item.name = name
            item.createdAt = .now
            let batch = Batch(context: context)
            batch.location = fridge
            batch.id = UUID()
            batch.addedAt = Calendar.current.date(byAdding: .day, value: -7, to: .now)
            batch.expiresAt = Calendar.current.date(byAdding: .day, value: days, to: .now)
            batch.level = level.rawValue
            batch.levelUpdatedAt = Calendar.current.date(byAdding: .day, value: -2, to: .now)
            batch.item = item
        }
        try? context.save()
        return persistence
    }()

    // Loaded once: a second model instance makes Core Data unable to map entities to their classes.
    private static let model = NSManagedObjectModel.mergedModel(from: [.main]) ?? NSManagedObjectModel()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Keepsy", managedObjectModel: Self.model)
        let description = container.persistentStoreDescriptions.first
        if inMemory {
            description?.url = URL(fileURLWithPath: "/dev/null")
        }
        // Unit tests run the app unsigned, and CloudKit without its entitlement crashes at launch.
        if inMemory || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            description?.cloudKitContainerOptions = nil
        } else {
            description?.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainer)
            description?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        // A failed load leaves no stores; the app shows StoreErrorView instead of crashing.
        container.loadPersistentStores { _, _ in }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        Self.seedDefaultLocations(in: container.viewContext)
    }

    static let cloudKitContainer = "iCloud.com.noahchoi.keepsy"

    var isLoaded: Bool { !container.persistentStoreCoordinator.persistentStores.isEmpty }

    /// Back to a fresh install: everything removed, default locations recreated. Settings are kept.
    static func deleteAll(in context: NSManagedObjectContext) throws {
        for entity in model.entities {
            guard let name = entity.name else { continue }
            try context.fetch(NSFetchRequest<NSManagedObject>(entityName: name)).forEach(context.delete)
        }
        try context.save()
        seedDefaultLocations(in: context)
    }

    /// Every device seeds Kitchen › Fridge / Freezer before its first sync, so after an import there can be two of each.
    /// Same-named siblings merge into the one with the smallest id, so all devices keep the same record.
    static func mergeDuplicateLocations(in context: NSManagedObjectContext) {
        let roots = Location.fetchRequest()
        roots.predicate = NSPredicate(format: "parent == nil")
        guard let top = try? context.fetch(roots) else { return }
        merge(top)
        if context.hasChanges { try? context.save() }
    }

    private static func merge(_ siblings: [Location]) {
        for group in Dictionary(grouping: siblings, by: { $0.name ?? "" }).values {
            let sorted = group.sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
            guard let keeper = sorted.first else { continue }
            for duplicate in sorted.dropFirst() {
                keeper.isFreezer = keeper.isFreezer || duplicate.isFreezer
                for batch in (duplicate.batches as? Set<Batch>) ?? [] { batch.location = keeper }
                for item in (duplicate.lastUsedBy as? Set<Item>) ?? [] { item.lastLocation = keeper }
                for child in (duplicate.children as? Set<Location>) ?? [] { child.parent = keeper }
                duplicate.managedObjectContext?.delete(duplicate)
            }
            merge(((keeper.children as? Set<Location>) ?? []).map(\.self))
        }
    }

    private static func seedDefaultLocations(in context: NSManagedObjectContext) {
        guard (try? context.count(for: Location.fetchRequest())) == 0 else { return }
        let kitchen = Location.make(String(localized: "Kitchen"), parent: nil, in: context)
        Location.make(String(localized: "Fridge"), parent: kitchen, in: context)
        Location.make(String(localized: "Freezer"), parent: kitchen, in: context).isFreezer = true
        try? context.save()
    }
}
