import Foundation

/// What the app hands the "Expiring soon" widget. The widget never opens the synced store; it reads this copy.
struct WidgetSnapshot: Codable {
    struct Entry: Codable, Hashable {
        let name: String
        let expiresAt: Date
    }

    static let appGroup = "group.com.noahchoi.keepsy"
    private static let key = "widget.snapshot"

    /// Soonest first.
    var entries: [Entry] = []

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> WidgetSnapshot {
        guard let data = defaults?.data(forKey: key), let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return WidgetSnapshot()
        }
        return snapshot
    }

    func save(to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
        defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}
