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

    @Test func labels() {
        #expect(Expiry.label(daysLeft: 0) == "D-Day")
        #expect(Expiry.label(daysLeft: 3) == "D-3")
        #expect(Expiry.label(daysLeft: -2) == "D+2")
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

struct ReminderDigestTests {
    let calendar = Calendar(identifier: .gregorian)

    func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: .now)) ?? .now
    }

    @Test func listsOnlyItemsDueWithinWindowSoonestFirst() {
        let entries = [(name: "Eggs", expiresAt: day(5)), (name: "Milk", expiresAt: day(0)),
                       (name: "Old", expiresAt: day(-1)), (name: "Kimchi", expiresAt: day(30))]
        #expect(Reminders.digest(entries, on: day(0), within: 7, calendar: calendar) == "Milk D-Day, Eggs D-5")
        #expect(Reminders.digest(entries, on: day(0), within: 3, calendar: calendar) == "Milk D-Day")
        #expect(Reminders.digest(entries, on: day(1), within: 3, calendar: calendar) == nil)
    }

    @Test func collapsesLongLists() throws {
        let entries = (1...5).map { (name: "I\($0)", expiresAt: day($0)) }
        let body = try #require(Reminders.digest(entries, on: day(0), within: 7, calendar: calendar))
        #expect(body.hasPrefix("I1 D-1, I2 D-2, I3 D-3"))
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

        let names = try Shopping.suggestions(in: context).compactMap(\.name)
        #expect(names == ["Empty", "Expired", "UsedUp"])
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
    @Test func seedsDefaultLocationsOnce() throws {
        let persistence = Persistence(inMemory: true)
        let locations = try persistence.container.viewContext.fetch(Location.fetchRequest())
        #expect(locations.count == 3)
        #expect(locations.filter { $0.parent == nil }.count == 1)
    }
}
