import CloudKit
import CoreData
import UIKit

/// Family sharing: the whole home is one CKShare. The owner's records stay in their private database inside the share's zone;
/// people who join read and write them through the shared store.
@MainActor
enum Household {
    private static var persistence: Persistence { .shared }
    private static var context: NSManagedObjectContext { persistence.container.viewContext }

    /// The share this device is part of, as owner or participant.
    static func currentShare() -> CKShare? {
        let stores = [persistence.privateStore, persistence.sharedStore].compactMap(\.self)
        return stores.lazy.compactMap { try? persistence.container.fetchShares(in: $0).first }.first
    }

    /// Opens the system sheet to invite family, or to see who is in and leave or stop sharing.
    static func presentSharing() async throws {
        let share: CKShare
        if let existing = currentShare() {
            share = existing
        } else {
            (_, share, _) = try await persistence.container.share(try allPrivateObjects(), to: nil)
            share[CKShare.SystemFieldKey.title] = String(localized: "Our home in Keepsy")
            share.publicPermission = .none
        }
        let controller = UICloudSharingController(share: share, container: CKContainer(identifier: Persistence.cloudKitContainer))
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = SharingDelegate.shared
        topViewController()?.present(controller, animated: true)
    }

    /// Records added on the owner's device land outside the share's zone; move them in so family sees them.
    static func shareNewObjects() async {
        guard let privateStore = persistence.privateStore,
              let share = try? persistence.container.fetchShares(in: privateStore).first,
              let objects = try? allPrivateObjects() else { return }
        let shared = (try? persistence.container.fetchShares(matching: objects.map(\.objectID))) ?? [:]
        let missing = objects.filter { shared[$0.objectID] == nil }
        guard !missing.isEmpty else { return }
        _ = try? await persistence.container.share(missing, to: share)
    }

    static func accept(_ metadata: CKShare.Metadata) async {
        guard metadata.participantRole != .owner, let sharedStore = persistence.sharedStore else { return }
        do {
            _ = try await persistence.container.acceptShareInvitations(from: [metadata], into: sharedStore)
            try moveAll(from: persistence.privateStore, to: sharedStore, in: context)
        } catch {
            context.rollback()
        }
    }

    /// Joining merges what was on this phone into the family's home: copies go to the shared store, originals are deleted.
    /// Same-named places and items are merged once the family's records arrive.
    static func moveAll(from source: NSPersistentStore?, to target: NSPersistentStore, in context: NSManagedObjectContext) throws {
        guard let source, let entities = context.persistentStoreCoordinator?.managedObjectModel.entities else { return }
        var copies: [NSManagedObjectID: NSManagedObject] = [:]
        var originals: [NSManagedObject] = []
        for entity in entities {
            guard let name = entity.name else { continue }
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            request.affectedStores = [source]
            for original in try context.fetch(request) {
                let copy = NSManagedObject(entity: entity, insertInto: context)
                context.assign(copy, to: target)
                copy.setValuesForKeys(original.dictionaryWithValues(forKeys: Array(entity.attributesByName.keys)))
                copies[original.objectID] = copy
                originals.append(original)
            }
        }
        for original in originals {
            guard let copy = copies[original.objectID] else { continue }
            for (name, relationship) in original.entity.relationshipsByName {
                if relationship.isToMany {
                    let related = (original.value(forKey: name) as? Set<NSManagedObject>) ?? []
                    copy.setValue(Set(related.compactMap { copies[$0.objectID] }), forKey: name)
                } else if let related = original.value(forKey: name) as? NSManagedObject {
                    copy.setValue(copies[related.objectID], forKey: name)
                }
            }
        }
        originals.forEach(context.delete)
        try context.save()
    }

    private static func allPrivateObjects() throws -> [NSManagedObject] {
        guard let privateStore = persistence.privateStore else { return [] }
        return try persistence.container.managedObjectModel.entities.compactMap(\.name).flatMap { name in
            let request = NSFetchRequest<NSManagedObject>(entityName: name)
            request.affectedStores = [privateStore]
            return try context.fetch(request)
        }
    }

    /// Settings is itself a sheet, so the sharing sheet goes on top of whatever is presented.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

private final class SharingDelegate: NSObject, UICloudSharingControllerDelegate {
    @MainActor static let shared = SharingDelegate()

    func itemTitle(for csc: UICloudSharingController) -> String? {
        String(localized: "Our home in Keepsy")
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: any Error) {}

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        guard let share = csc.share else { return }
        MainActor.assumeIsolated {
            guard let store = Persistence.shared.privateStore else { return }
            Persistence.shared.container.persistUpdatedShare(share, in: store, completion: { _, _ in })
        }
    }

    /// A participant leaving drops the family's records from this phone. The owner stopping keeps everything.
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        guard let share = csc.share, share.currentUserParticipant?.role != .owner else { return }
        MainActor.assumeIsolated {
            guard let store = Persistence.shared.sharedStore else { return }
            Persistence.shared.container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store, completion: { _, _ in })
        }
    }
}

/// The system hands accepted share links to the scene delegate, which SwiftUI apps only get through these adaptors.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let metadata = connectionOptions.cloudKitShareMetadata else { return }
        Task { await Household.accept(metadata) }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { await Household.accept(cloudKitShareMetadata) }
    }
}
