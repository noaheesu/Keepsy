import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Expiring", systemImage: "clock") {
                ExpiringView()
            }
            Tab("Locations", systemImage: "square.grid.2x2") {
                NavigationStack {
                    LocationList(parent: nil)
                        .navigationDestination(for: Location.self) { LocationList(parent: $0) }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
