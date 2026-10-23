import SwiftUI

enum Expiry {
    /// Items within this many days count as "soon" for badges and the daily reminder.
    static let soonDays = 7

    static func daysLeft(until date: Date, from now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func label(daysLeft: Int) -> String {
        switch daysLeft {
        case 0: "D-Day"
        case 1...: "D-\(daysLeft)"
        default: "D+\(-daysLeft)"
        }
    }

    static func color(daysLeft: Int) -> Color {
        switch daysLeft {
        case ...0: .red
        case 1...soonDays: .orange
        default: .secondary
        }
    }
}
