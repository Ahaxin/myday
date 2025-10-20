import Foundation
import CloudKit

enum CloudKitSubscriptions {
    static let entryChangesID = "entry-changes-subscription"

    static func ensureDatabaseSubscription(container: CKContainer = .default()) async {
        let db = container.privateCloudDatabase
        // Try fetch existing
        let exists: Bool = await withCheckedContinuation { continuation in
            db.fetch(withSubscriptionID: entryChangesID) { sub, _ in
                continuation.resume(returning: sub is CKDatabaseSubscription)
            }
        }
        if exists { return }

        let sub = CKDatabaseSubscription(subscriptionID: entryChangesID)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true // silent push for background refresh
        sub.notificationInfo = info
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            db.save(sub) { _, _ in continuation.resume() }
        }
    }
}
