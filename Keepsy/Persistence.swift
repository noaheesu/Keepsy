import CoreData

@MainActor
struct Persistence {
    static let shared = Persistence()

    static let preview: Persistence = {
        let persistence = Persistence(inMemory: true)
        let context = persistence.container.viewContext
        let fridge = try? context.fetch(Location.fetchRequest()).first { $0.name == String(localized: "Fridge") }
        for (name, days) in [("Milk", -1), ("Tofu", 0), ("Eggs", 5), ("Kimchi", 30)] {
            let item = Item(context: context)
            item.id = UUID()
            item.name = name
            item.createdAt = .now
            let batch = Batch(context: context)
            batch.location = fridge
            batch.id = UUID()
            batch.addedAt = .now
            batch.expiresAt = Calendar.current.date(byAdding: .day, value: days, to: .now)
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
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Failed to load store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        seedDefaultLocations()
    }

    // shortcut: seeding per device will duplicate defaults once CloudKit sync is on, dedupe when enabling sync.
    private func seedDefaultLocations() {
        let context = container.viewContext
        guard (try? context.count(for: Location.fetchRequest())) == 0 else { return }
        let kitchen = Location.make(String(localized: "Kitchen"), parent: nil, in: context)
        Location.make(String(localized: "Fridge"), parent: kitchen, in: context)
        Location.make(String(localized: "Freezer"), parent: kitchen, in: context)
        try? context.save()
    }
}
