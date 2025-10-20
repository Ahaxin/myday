import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                EntryListView(entries: appModel.entries)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            LargeTitleView(title: "My Day", symbolName: "sparkles")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: appModel.refresh) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    .toolbarBackground(AppTheme.playfulGradient.opacity(0.18), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Entries", systemImage: "mic")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppTheme.ocean, AppTheme.bubblegum)
            }

            NavigationStack {
                ExportListView(exports: appModel.exports)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .principal) {
                            LargeTitleView(title: "Exports", symbolName: "tray.and.arrow.down")
                        }
                    }
                    .toolbarBackground(AppTheme.playfulGradient.opacity(0.18), for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
            }
            .tabItem {
                Label("Exports", systemImage: "tray.and.arrow.down")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppTheme.grape, AppTheme.sunny)
            }
        }
        .toolbarBackground(AppTheme.playfulGradient.opacity(0.10), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(AppTheme.playfulGradient.opacity(0.08))
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
