import SwiftUI

@main
struct MyDayApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .onReceive(NotificationCenter.default.publisher(for: .cloudKitDidChange)) { _ in
                    appModel.refresh()
                }
                .tint(AppTheme.accent)
                .fontDesign(.rounded)
        }
    }
}
