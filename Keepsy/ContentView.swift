import SwiftUI

struct ContentView: View {
    @AppStorage("onboarded") private var onboarded = false

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
            Tab("Shopping", systemImage: "cart") {
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
