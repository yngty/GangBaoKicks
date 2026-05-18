import SwiftUI

@main
struct GangBaoKicksWatchApp: App {
    @StateObject private var store = KickStore()
    @StateObject private var syncService = WatchSyncService()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(store)
                .environmentObject(syncService)
                .onAppear {
                    syncService.configure(store: store)
                }
        }
    }
}
