import UIKit
import CloudKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Best-effort: ensure CloudKit subscription exists
        Task { await CloudKitSubscriptions.ensureDatabaseSubscription() }

        // Request permission for silent notifications (not strictly required for CloudKit)
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // CloudKit push delivered — notify app to refresh
        NotificationCenter.default.post(name: .cloudKitDidChange, object: nil)
        completionHandler(.newData)
    }
}

