import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        TabView {
            NavigationStack {
                EntryListView(entries: appModel.entries)
                    .navigationTitle("My Day")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button(action: appModel.refresh) {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Entries", systemImage: "mic")
            }

            NavigationStack {
                ExportListView(exports: appModel.exports)
                    .navigationTitle("Exports")
            }
            .tabItem {
                Label("Exports", systemImage: "tray.and.arrow.down")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppModel())
}
