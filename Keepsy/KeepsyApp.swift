import SwiftUI

@main
struct KeepsyApp: App {
    private let persistence = Persistence.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
