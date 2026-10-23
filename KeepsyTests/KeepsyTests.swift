import CoreData
import Foundation
import Testing
@testable import Keepsy

struct ExpiryTests {
    let calendar = Calendar(identifier: .gregorian)

    func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .distantPast
    }

    @Test func daysLeftIgnoresTimeOfDay() {
        #expect(Expiry.daysLeft(until: date(24, 1), from: date(23, 23), calendar: calendar) == 1)
        #expect(Expiry.daysLeft(until: date(23, 0), from: date(23, 23), calendar: calendar) == 0)
        #expect(Expiry.daysLeft(until: date(21, 12), from: date(23, 8), calendar: calendar) == -2)
    }

    @Test func remainingShareIsClamped() {
        #expect(Expiry.remaining(addedAt: date(20, 0), expiresAt: date(30, 0), now: date(25, 0)) == 0.5)
        #expect(Expiry.remaining(addedAt: date(20, 0), expiresAt: date(30, 0), now: date(31, 0)) == 0)
        #expect(Expiry.remaining(addedAt: date(20, 0), expiresAt: date(20, 0), now: date(20, 0)) == 0)
    }

    @Test func urgencyBoundaries() {
        #expect(Expiry.Urgency(daysLeft: -1) == .overdue)
        #expect(Expiry.Urgency(daysLeft: 1) == .imminent)
        #expect(Expiry.Urgency(daysLeft: 7) == .thisWeek)
        #expect(Expiry.Urgency(daysLeft: 8) == .later)
    }

}

@MainActor
struct BatchDraftTests {
    let context = Persistence(inMemory: true).container.viewContext

    @Test func newBatchWithKnownNameReusesItem() throws {
        var draft = BatchDraft()
        draft.name = "Milk"
        let first = try draft.save(to: nil, in: context)
        draft.name = " milk "
        let second = try draft.save(to: nil, in: context)
        #expect(first.item == second.item)
        #expect(try context.count(for: Item.fetchRequest()) == 1)
    }

    @Test func levelTimestampMovesOnlyWhenLevelChanges() throws {
        var draft = BatchDraft()
        draft.name = "Milk"
        let batch = try draft.save(to: nil, in: context)
        let stamped = try #require(batch.levelUpdatedAt)

        draft.quantity = 2
        try draft.save(to: batch, in: context)
        #expect(batch.levelUpdatedAt == stamped)

        draft.level = .half
        try draft.save(to: batch, in: context)
        #expect(batch.levelUpdatedAt != stamped)
    }

    @Test func editingCanRemovePhotoButNewBatchKeepsIt() throws {
        var draft = BatchDraft()
        draft.name = "Milk"
        draft.photo = Data([1])
        let batch = try draft.save(to: nil, in: context)

        var again = BatchDraft()
        again.name = "Milk"
        try again.save(to: nil, in: context)
        #expect(batch.item?.photo == Data([1]))

        var edit = BatchDraft(batch: batch)
        edit.photo = nil
        try edit.save(to: batch, in: context)
        #expect(batch.item?.photo == nil)
    }
}

struct PackageDateTests {
    let calendar = Calendar(identifier: .gregorian)
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 23)) ?? .now }

    func ymd(_ text: String) -> [Int]? {
        ymd(text, region: "ko_KR")
    }

    func ymd(_ text: String, region: String) -> [Int]? {
        PackageDate.parse(text, now: now, calendar: calendar, locale: Locale(identifier: region)).map {
            let c = calendar.dateComponents([.year, .month, .day], from: $0)
            return [c.year ?? 0, c.month ?? 0, c.day ?? 0]
        }
    }

    @Test func readsCommonKoreanFormats() {
        #expect(ymd("소비기한: 2026.10.25까지") == [2026, 10, 25])
        #expect(ymd("26-11-03") == [2026, 11, 3])
        #expect(ymd("2027년 1월 5일") == [2027, 1, 5])
        #expect(ymd("20261231") == [2026, 12, 31])
        #expect(ymd("2026. 10. 25") == [2026, 10, 25])
    }

    @Test func readsUSAndEuropeanFormats() {
        #expect(ymd("BEST BY 10/25/2026", region: "en_US") == [2026, 10, 25])
        #expect(ymd("05/03/2026", region: "en_US") == [2026, 5, 3])
        #expect(ymd("05/03/2026", region: "de_DE") == [2026, 3, 5])
        #expect(ymd("25.10.2026", region: "en_US") == [2026, 10, 25])
        #expect(ymd("EXP 25 OCT 2026", region: "en_GB") == [2026, 10, 25])
        #expect(ymd("Use by Oct 25, 2026", region: "en_US") == [2026, 10, 25])
        #expect(ymd("Best before NOV 2026", region: "en_GB") == [2026, 11, 30])
        #expect(ymd("25/10/26", region: "en_GB") == [2026, 10, 25])
        #expect(ymd("Lot 2026.10.01 EXP 31.12.2026", region: "de_DE") == [2026, 12, 31])
    }

    @Test func prefersLatestDateAndRejectsNonsense() {
        #expect(ymd("제조일 2026.10.01 소비기한 2026.10.20") == [2026, 10, 20])
        #expect(ymd("2026.13.40") == nil)
        #expect(ymd("Lot 12.10.05") == nil)
        #expect(ymd("no date here") == nil)
    }
}

struct ReminderDigestTests {
    let calendar = Calendar(identifier: .gregorian)

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now)) ?? .now
    }

    @Test func listsOnlyItemsDueWithinWindowSoonestFirst() {
        let entries = [(name: "Eggs", expiresAt: day(5)), (name: "Milk", expiresAt: day(0)),
                       (name: "Old", expiresAt: day(-1)), (name: "Kimchi", expiresAt: day(30))]
        #expect(Reminders.digest(entries, on: day(0), within: 7, calendar: calendar) == "Milk \(Expiry.label(daysLeft: 0)), Eggs \(Expiry.label(daysLeft: 5))")
        #expect(Reminders.digest(entries, on: day(0), within: 3, calendar: calendar) == "Milk \(Expiry.label(daysLeft: 0))")
        #expect(Reminders.digest(entries, on: day(1), within: 3, calendar: calendar) == nil)
    }

    @Test func collapsesLongLists() throws {
        let entries = (1...5).map { (name: "I\($0)", expiresAt: day($0)) }
        let body = try #require(Reminders.digest(entries, on: day(0), within: 7, calendar: calendar))
        #expect(body.hasPrefix("I1 \(Expiry.label(daysLeft: 1)), I2 \(Expiry.label(daysLeft: 2))"))
        #expect(body.contains("2"))
    }
}

@MainActor
struct ReAddTests {
    let context = Persistence(inMemory: true).container.viewContext

    @Test func fillCopiesLastPlaceAndShelfLife() throws {
        let fridge = Location.make("Fridge", parent: nil, in: context)
        var draft = BatchDraft(location: fridge)
        draft.name = "Milk"
        draft.expiresAt = Calendar.current.date(byAdding: .day, value: 10, to: .now) ?? .now
        let batch = try draft.save(to: nil, in: context)
        let item = try #require(batch.item)
        context.delete(batch)

        let later = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        var again = BatchDraft()
        again.fill(from: item, now: later)
        #expect(again.location == fridge)
        #expect(Expiry.daysLeft(until: again.expiresAt, from: later) == 10)
    }
}

@MainActor
struct ShoppingTests {
    let context = Persistence(inMemory: true).container.viewContext

    func stock(_ name: String, level: Level = .full, daysLeft: Int? = 5) throws -> Item? {
        var draft = BatchDraft()
        draft.name = name
        draft.level = level
        draft.hasExpiry = daysLeft != nil
        draft.expiresAt = Calendar.current.date(byAdding: .day, value: daysLeft ?? 0, to: .now) ?? .now
        return try draft.save(to: nil, in: context).item
    }

    @Test func suggestsOnlyItemsWithNothingUsableLeft() throws {
        _ = try stock("Fresh")
        _ = try stock("NoExpiry", daysLeft: nil)
        _ = try stock("Empty", level: .empty)
        _ = try stock("Expired", daysLeft: -1)
        let usedUp = try stock("UsedUp")
        (usedUp?.batches as? Set<Batch>)?.forEach(context.delete)

        let names = try Shopping.suggestions(in: context).compactMap(\.item.name)
        #expect(names == ["Empty", "Expired", "UsedUp"])
    }

    @Test func useOneDecrementsThenRemoves() throws {
        let item = try #require(try stock("Eggs", level: .half))
        let batch = try #require((item.batches as? Set<Batch>)?.first)
        batch.quantity = 2
        batch.useOne()
        #expect(batch.quantity == 1)
        #expect(batch.level == Level.full.rawValue)
        batch.useOne()
        try context.save()
        #expect(try Shopping.suggestions(in: context).compactMap(\.item.name) == ["Eggs"])
    }

    @Test func putAwayRestocksBoughtItemsWithLastShelfLife() throws {
        let milk = try #require(try stock("Milk", daysLeft: 10))
        (milk.batches as? Set<Batch>)?.forEach(context.delete)
        let soap = try #require(try stock("Soap", daysLeft: nil))
        (soap.batches as? Set<Batch>)?.forEach(context.delete)
        try Shopping.add("Milk", in: context)
        try Shopping.add("Soap", in: context)
        try Shopping.add("Unknown", in: context)
        try context.fetch(ShoppingEntry.fetchRequest()).forEach { $0.isDone = true }

        try Shopping.putAway(in: context)

        #expect(try context.count(for: ShoppingEntry.fetchRequest()) == 0)
        let milkBatch = try #require((milk.batches as? Set<Batch>)?.first)
        #expect(milkBatch.expiresAt.map { Expiry.daysLeft(until: $0) } == 10)
        #expect((soap.batches as? Set<Batch>)?.first?.expiresAt == nil)
        #expect(try context.count(for: Item.fetchRequest()) == 2)
    }

    @Test func suggestsUsualRebuyOnceItsRhythmHasPassed() throws {
        let milk = try #require(try stock("Milk"))
        let start = Date.now.addingTimeInterval(-20 * 86_400)
        milk.lastBoughtAt = nil
        milk.recordPurchase(at: start)
        milk.recordPurchase(at: start.addingTimeInterval(4 * 86_400))
        milk.recordPurchase(at: start.addingTimeInterval(4.2 * 86_400))
        milk.recordPurchase(at: start.addingTimeInterval(10 * 86_400))
        #expect(milk.restockDays == 5)

        #expect(try Shopping.suggestions(in: context, now: start.addingTimeInterval(13 * 86_400)).isEmpty)
        let due = try Shopping.suggestions(in: context, now: start.addingTimeInterval(15 * 86_400))
        #expect(due.map(\.reason) == [.usual(days: 5)])
    }

    @Test func usageIsLoggedAsUsedOrWasted() throws {
        let item = try #require(try stock("Bread"))
        let batch = try #require((item.batches as? Set<Batch>)?.first)
        batch.quantity = 2
        batch.useOne()
        batch.useOne(wasted: true)
        try context.save()
        let events = (item.usageEvents as? Set<UsageEvent>) ?? []
        #expect(events.count == 2)
        #expect(events.filter(\.wasted).count == 1)
    }

    @Test func wasteStatsCountRecentEventsAndRankWastedItems() throws {
        for (name, wasted) in [("Bread", true), ("Bread", true), ("Milk", true), ("Milk", false), ("Eggs", false)] {
            let event = UsageEvent(context: context)
            event.at = .now
            event.wasted = wasted
            event.item = try Item.named(name, in: context) ?? stock(name)
        }
        let old = UsageEvent(context: context)
        old.at = Calendar.current.date(byAdding: .day, value: -31, to: .now)
        old.wasted = true
        try context.save()

        let stats = try Waste.stats(in: context)
        #expect(stats.used == 2)
        #expect(stats.wasted == 3)
        #expect(stats.wastedShare == 0.6)
        #expect(stats.topWasted.map(\.name) == ["Bread", "Milk"])
    }

    @Test func widgetSnapshotListsSoonestUsableBatches() throws {
        _ = try stock("Later", daysLeft: 9)
        _ = try stock("Soon", daysLeft: 1)
        _ = try stock("Empty", level: .empty, daysLeft: 0)
        _ = try stock("Undated", daysLeft: nil)

        let snapshot = WidgetSnapshot(context: context)
        #expect(snapshot.entries.map(\.name) == ["Soon", "Later"])

        let defaults = try #require(UserDefaults(suiteName: "WidgetSnapshotTests"))
        snapshot.save(to: defaults)
        #expect(WidgetSnapshot.load(from: defaults).entries == snapshot.entries)
        defaults.removePersistentDomain(forName: "WidgetSnapshotTests")
    }

    @Test func putAwayFlagsGuessedDatesUntilEdited() throws {
        let milk = try #require(try stock("Milk", daysLeft: 10))
        (milk.batches as? Set<Batch>)?.forEach(context.delete)
        try Shopping.add("Milk", in: context)
        try context.fetch(ShoppingEntry.fetchRequest()).forEach { $0.isDone = true }
        try Shopping.putAway(in: context)

        let batch = try #require((milk.batches as? Set<Batch>)?.first)
        #expect(batch.needsDateCheck)
        try BatchDraft(batch: batch).save(to: batch, in: context)
        #expect(!batch.needsDateCheck)
    }

    @Test func freezingMovesAndExtends() throws {
        let item = try #require(try stock("Beef", daysLeft: -2))
        let batch = try #require((item.batches as? Set<Batch>)?.first)
        let freezer = Location.make("Freezer", parent: nil, in: context)
        batch.freeze(into: freezer)
        #expect(batch.location == freezer)
        #expect(batch.expiresAt.map { Expiry.daysLeft(until: $0) } ?? 0 >= 28)
    }

    @Test func typedEntryLinksItemAndHidesSuggestion() throws {
        _ = try stock("Milk", level: .empty)
        try Shopping.add(" milk ", in: context)
        #expect(try Shopping.suggestions(in: context).isEmpty)
    }
}

@MainActor
struct LocationTests {
    let context = Persistence(inMemory: true).container.viewContext

    @Test func deleteMovesContentsToParent() throws {
        let room = Location.make("Room", parent: nil, in: context)
        let shelf = Location.make("Shelf", parent: room, in: context)
        let box = Location.make("Box", parent: shelf, in: context)
        var draft = BatchDraft(location: shelf)
        draft.name = "Soap"
        let batch = try draft.save(to: nil, in: context)

        shelf.deleteMovingContents()
        try context.save()

        #expect(batch.location == room)
        #expect(box.parent == room)
        #expect(try context.count(for: Batch.fetchRequest()) == 1)
    }

    @Test func depthIsCapped() {
        let a = Location.make("A", parent: nil, in: context)
        let b = Location.make("B", parent: a, in: context)
        let c = Location.make("C", parent: b, in: context)
        #expect(a.canHaveChildren && b.canHaveChildren)
        #expect(!c.canHaveChildren)
        #expect(c.path == "A › B › C")
    }

    @Test func newLocationGoesLastAmongSiblings() {
        let a = Location.make("A", parent: nil, in: context)
        let first = Location.make("X", parent: a, in: context)
        let second = Location.make("Y", parent: a, in: context)
        #expect(first.sortOrder == 0)
        #expect(second.sortOrder == 1)
    }
}

@MainActor
struct PersistenceTests {
    @Test func deleteAllLeavesOnlyDefaultLocations() throws {
        let context = Persistence(inMemory: true).container.viewContext
        var draft = BatchDraft()
        draft.name = "Milk"
        try draft.save(to: nil, in: context)
        try Shopping.add("Eggs", in: context)

        try Persistence.deleteAll(in: context)

        #expect(try context.count(for: Item.fetchRequest()) == 0)
        #expect(try context.count(for: Batch.fetchRequest()) == 0)
        #expect(try context.count(for: ShoppingEntry.fetchRequest()) == 0)
        #expect(try context.count(for: Location.fetchRequest()) == 3)
    }

    @Test func seedsDefaultLocationsOnce() throws {
        let persistence = Persistence(inMemory: true)
        let locations = try persistence.container.viewContext.fetch(Location.fetchRequest())
        #expect(locations.count == 3)
        #expect(locations.filter { $0.parent == nil }.count == 1)
    }

    @Test func syncedDuplicateDefaultsMergeIntoOne() throws {
        let context = Persistence(inMemory: true).container.viewContext
        let kitchen2 = Location.make(String(localized: "Kitchen"), parent: nil, in: context)
        let fridge2 = Location.make(String(localized: "Fridge"), parent: kitchen2, in: context)
        let batch = Batch(context: context)
        batch.location = fridge2
        try context.save()

        Persistence.mergeDuplicateLocations(in: context)
        let names = try context.fetch(Location.fetchRequest()).compactMap(\.name).sorted()
        #expect(names == [String(localized: "Freezer"), String(localized: "Fridge"), String(localized: "Kitchen")].sorted())
        #expect(batch.location?.name == String(localized: "Fridge"))
        #expect(batch.location?.parent?.name == String(localized: "Kitchen"))
    }
}
