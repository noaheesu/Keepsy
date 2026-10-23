import CoreData
import UserNotifications

enum Reminders {
    static let enabledKey = "reminders.enabled"
    static let minutesKey = "reminders.minutes"
    static let daysKey = "reminders.days"
    static let defaultMinutes = 9 * 60
    static let defaultDays = 7

    // shortcut: daily digests are precomputed for the next 14 days and refreshed whenever the app is opened or data changes,
    // so they stop if the app goes unopened for two weeks; add a BGAppRefreshTask if that matters.
    private static let scheduledDays = 14
    private static let ids = (0..<scheduledDays).map { "digest-\($0)" }

    @MainActor
    static func reschedule(in context: NSManagedObjectContext, defaults: UserDefaults = .standard) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard defaults.object(forKey: enabledKey) as? Bool ?? true else { return }
        let minutes = defaults.object(forKey: minutesKey) as? Int ?? defaultMinutes
        let days = defaults.object(forKey: daysKey) as? Int ?? defaultDays

        let request = Batch.fetchRequest()
        request.predicate = NSPredicate(format: "expiresAt != nil AND level != %d", Level.empty.rawValue)
        let entries = ((try? context.fetch(request)) ?? []).compactMap { batch in
            batch.expiresAt.map { (name: batch.item?.name ?? "", expiresAt: $0) }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var requests: [UNNotificationRequest] = []
        for (offset, id) in ids.enumerated() {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
                  fire > .now,
                  let body = digest(entries, on: day, within: days, calendar: calendar)
            else { continue }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Expiring soon")
            content.body = body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false
            )
            requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        // Asking only once there is something to remind about keeps the permission prompt in context.
        guard !requests.isEmpty, (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for request in requests {
            try? await center.add(request)
        }
    }

    /// "Milk D-Day, Tofu D-2, Eggs D-5 and 2 more", or nil when nothing is due within `days` of `day`.
    static func digest(_ entries: [(name: String, expiresAt: Date)], on day: Date, within days: Int, calendar: Calendar = .current) -> String? {
        let due = entries
            .map { (name: $0.name, daysLeft: Expiry.daysLeft(until: $0.expiresAt, from: day, calendar: calendar)) }
            .filter { (0...days).contains($0.daysLeft) }
            .sorted { $0.daysLeft < $1.daysLeft }
        guard !due.isEmpty else { return nil }
        let shown = due.prefix(3).map { "\($0.name) \(Expiry.label(daysLeft: $0.daysLeft))" }.joined(separator: ", ")
        return due.count > 3 ? String(localized: "\(shown) and \(due.count - 3) more") : shown
    }
}
