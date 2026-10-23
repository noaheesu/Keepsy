import CoreData
import WidgetKit

extension WidgetSnapshot {
    /// Enough rows for the largest widget; the widget works out days left itself so it stays right past midnight.
    init(context: NSManagedObjectContext, limit: Int = 10) {
        entries = Reminders.expiring(in: context)
            .sorted { $0.expiresAt < $1.expiresAt }
            .prefix(limit)
            .map { Entry(name: $0.name, expiresAt: $0.expiresAt) }
    }

    @MainActor
    static func refresh(from context: NSManagedObjectContext) {
        let snapshot = WidgetSnapshot(context: context)
        guard snapshot.entries != load().entries else { return }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
