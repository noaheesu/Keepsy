import SwiftUI

enum Expiry {
    /// Items within this many days count as "soon" for badges and the daily reminder.
    static let soonDays = 7

    static func daysLeft(until date: Date, from now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// "D-3" in Korean, "3 days" in English: the D-day notation is only familiar in some places.
    static func label(daysLeft: Int) -> String {
        switch daysLeft {
        case 0: String(localized: "D-Day")
        case 1...: String(localized: "D-\(daysLeft)")
        default: String(localized: "D+\(-daysLeft)")
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
