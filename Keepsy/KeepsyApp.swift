import SwiftUI

@main
struct KeepsyApp: App {
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
                rescheduleReminders()
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                rescheduleReminders()
            }
        }
    }

    private func rescheduleReminders() {
        Task { await Reminders.reschedule(in: persistence.container.viewContext) }
    }
}
