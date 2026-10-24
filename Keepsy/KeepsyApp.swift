import SwiftUI

@main
struct KeepsyApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let persistence = Persistence.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if persistence.isLoaded {
                    ContentView()
                } else {
                    StoreErrorView()
                }
            }
            .environment(\.managedObjectContext, persistence.container.viewContext)
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave, object: persistence.container.viewContext)) { _ in
                refreshAfterChange()
            }
            // Posted off the main thread whenever a sync import lands.
            .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
                Persistence.mergeDuplicates(in: persistence.container.viewContext)
                // Leaving a household empties the app; start again from the default places.
                Persistence.seedDefaultLocations(in: persistence.container.viewContext)
                WidgetSnapshot.refresh(from: persistence.container.viewContext)
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                refreshAfterChange()
            }
        }
    }

    private func refreshAfterChange() {
        WidgetSnapshot.refresh(from: persistence.container.viewContext)
        Task {
            await Household.shareNewObjects()
            await Reminders.reschedule(in: persistence.container.viewContext)
        }
    }
}
