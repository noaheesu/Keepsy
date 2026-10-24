import SwiftUI

struct ContentView: View {
    @AppStorage("onboarded") private var onboarded = false
    // Launch with -tab 1 or 2 to open another tab (screenshots).
    @State private var tab = UserDefaults.standard.integer(forKey: "tab")

    var body: some View {
        TabView(selection: $tab) {
            Tab("Expiring", systemImage: "clock", value: 0) {
                ExpiringView()
            }
            Tab("Locations", systemImage: "square.grid.2x2", value: 1) {
                NavigationStack {
                    LocationList(parent: nil)
                        .navigationDestination(for: Location.self) { LocationList(parent: $0) }
                }
            }
            Tab("Shopping", systemImage: "cart", value: 2) {
                ShoppingView()
            }
        }
        .fullScreenCover(isPresented: Binding { !onboarded } set: { onboarded = !$0 }) {
            OnboardingView { onboarded = true }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, Persistence.preview.container.viewContext)
}
