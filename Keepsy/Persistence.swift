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
        // shortcut: CloudKit off until a paid developer account exists; set cloudKitContainerOptions to enable sync/sharing.
        description?.cloudKitContainerOptions = nil
        // A failed load leaves no stores; the app shows StoreErrorView instead of crashing.
        container.loadPersistentStores { _, _ in }
        container.viewContext.automaticallyMergesChangesFromParent = true
        Self.seedDefaultLocations(in: container.viewContext)
    }

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

    // shortcut: seeding per device will duplicate defaults once CloudKit sync is on, dedupe when enabling sync.
    private static func seedDefaultLocations(in context: NSManagedObjectContext) {
        guard (try? context.count(for: Location.fetchRequest())) == 0 else { return }
        let kitchen = Location.make(String(localized: "Kitchen"), parent: nil, in: context)
        Location.make(String(localized: "Fridge"), parent: kitchen, in: context)
        Location.make(String(localized: "Freezer"), parent: kitchen, in: context).isFreezer = true
        try? context.save()
    }
}
