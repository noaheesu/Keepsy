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
        case ...0: .overdue
        case 1...soonDays: .soon
        default: .fresh
        }
    }

    /// Share of the shelf life still ahead, 1 when just bought and 0 on the last day.
    static func remaining(addedAt: Date, expiresAt: Date, now: Date = .now) -> Double {
        let total = expiresAt.timeIntervalSince(addedAt)
        guard total > 0 else { return 0 }
        return min(max(expiresAt.timeIntervalSince(now) / total, 0), 1)
    }

    /// How many dates fall on each of the next `days` days, today first.
    static func dueCounts(_ dates: [Date], days: Int = soonDays, from now: Date = .now, calendar: Calendar = .current) -> [Int] {
        var counts = Array(repeating: 0, count: days)
        for date in dates {
            let offset = daysLeft(until: date, from: now, calendar: calendar)
            if counts.indices.contains(offset) {
                counts[offset] += 1
            }
        }
        return counts
    }

    enum Urgency: CaseIterable {
        case overdue, imminent, thisWeek, later

        init(daysLeft: Int) {
            switch daysLeft {
            case ..<0: self = .overdue
            case 0...1: self = .imminent
            case 2...Expiry.soonDays: self = .thisWeek
            default: self = .later
            }
        }

        var title: LocalizedStringResource {
            switch self {
            case .overdue: "Past date"
            case .imminent: "Today or tomorrow"
            case .thisWeek: "This week"
            case .later: "Later"
            }
        }

        var color: Color {
            switch self {
            case .overdue, .imminent: .overdue
            case .thisWeek: .soon
            case .later: .secondary
            }
        }
    }
}
