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
        } else if let description {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainer)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            // Households other people shared with this account.
            if let shared = description.copy() as? NSPersistentStoreDescription {
                shared.url = description.url?.deletingLastPathComponent().appendingPathComponent("Keepsy-shared.sqlite")
                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainer)
                options.databaseScope = .shared
                shared.cloudKitContainerOptions = options
                container.persistentStoreDescriptions.append(shared)
            }
        }
        // A failed load leaves no stores; the app shows StoreErrorView instead of crashing.
        container.loadPersistentStores { _, _ in }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        Self.seedDefaultLocations(in: container.viewContext)
        NotificationCenter.default.addObserver(forName: .NSManagedObjectContextWillSave, object: container.viewContext, queue: nil) { [self] _ in
            MainActor.assumeIsolated { assignInsertsToJoinedHousehold() }
        }
    }

    var privateStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first { $0.url?.lastPathComponent != "Keepsy-shared.sqlite" }
    }

    var sharedStore: NSPersistentStore? {
        container.persistentStoreCoordinator.persistentStores.first { $0.url?.lastPathComponent == "Keepsy-shared.sqlite" }
    }

    /// True after accepting someone else's household; everything then lives in their share.
    var hasJoinedHousehold: Bool {
        guard let sharedStore else { return false }
        return !((try? container.fetchShares(in: sharedStore)) ?? []).isEmpty
    }

    /// A joined household's records can't relate to ones in the private store, so new records go to the shared store too.
    private func assignInsertsToJoinedHousehold() {
        guard let sharedStore, hasJoinedHousehold else { return }
        let context = container.viewContext
        for object in context.insertedObjects where object.objectID.persistentStore == nil {
            context.assign(object, to: sharedStore)
        }
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

    /// Every device seeds Kitchen › Fridge / Freezer before its first sync, and joining a household brings in a second "Milk",
    /// so after an import there can be two of each. Same-named places (among siblings) and items merge into the one
    /// with the smallest id, so all devices keep the same record.
    static func mergeDuplicates(in context: NSManagedObjectContext) {
        let roots = Location.fetchRequest()
        roots.predicate = NSPredicate(format: "parent == nil")
        guard let top = try? context.fetch(roots), let items = try? context.fetch(Item.fetchRequest()) else { return }
        merge(top)
        merge(items)
        if context.hasChanges { try? context.save() }
    }

    private static func merge(_ items: [Item]) {
        for group in Dictionary(grouping: items, by: { ($0.name ?? "").lowercased() }).values {
            let sorted = group.sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
            guard let keeper = sorted.first else { continue }
            for duplicate in sorted.dropFirst() {
                keeper.photo = keeper.photo ?? duplicate.photo
                keeper.lastLocation = keeper.lastLocation ?? duplicate.lastLocation
                if keeper.shelfLifeDays == 0 { keeper.shelfLifeDays = duplicate.shelfLifeDays }
                if keeper.restockDays == 0 { keeper.restockDays = duplicate.restockDays }
                keeper.lastBoughtAt = [keeper.lastBoughtAt, duplicate.lastBoughtAt].compactMap(\.self).max()
                for batch in (duplicate.batches as? Set<Batch>) ?? [] { batch.item = keeper }
                for event in (duplicate.usageEvents as? Set<UsageEvent>) ?? [] { event.item = keeper }
                for entry in (duplicate.shoppingEntries as? Set<ShoppingEntry>) ?? [] { entry.item = keeper }
                duplicate.managedObjectContext?.delete(duplicate)
            }
        }
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

    static func seedDefaultLocations(in context: NSManagedObjectContext) {
        guard (try? context.count(for: Location.fetchRequest())) == 0 else { return }
        let kitchen = Location.make(String(localized: "Kitchen"), parent: nil, in: context)
        Location.make(String(localized: "Fridge"), parent: kitchen, in: context)
        Location.make(String(localized: "Freezer"), parent: kitchen, in: context).isFreezer = true
        try? context.save()
    }
}
