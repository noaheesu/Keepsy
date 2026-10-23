import SwiftUI

/// Shown instead of the app when the database can't be opened, so a bad store never crashes on launch.
struct StoreErrorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Keepsy can't open your items", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Close Keepsy and open it again. If this keeps happening, let us know and we'll help.")
        } actions: {
            if let support = AppLinks.support {
                Link("Contact Support", destination: support)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    StoreErrorView()
}
